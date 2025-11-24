package clients

import (
	"encoding/json"
	"fmt"
	"os"

	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/aws/session"
	"github.com/aws/aws-sdk-go/service/lambda"
	"github.com/rs/zerolog"
)

type GovernanceRequest struct {
	Service string `json:"service"`
	Intent  string `json:"intent"`
}

type GovernanceResponse struct {
	Allowed bool   `json:"allowed"`
	Reason  string `json:"reason,omitempty"`
}

type GovernanceClient struct {
	lambdaClient *lambda.Lambda
	logger       zerolog.Logger
	functionName string
}

func NewGovernanceClient(logger zerolog.Logger) (*GovernanceClient, error) {
	region := os.Getenv("AWS_REGION")
	if region == "" {
		region = "us-east-1"
	}

	sess, err := session.NewSession(&aws.Config{
		Region: aws.String(region),
	})
	if err != nil {
		return nil, fmt.Errorf("failed to create AWS session: %w", err)
	}

	functionName := os.Getenv("GOVERNANCE_FUNCTION_NAME")
	if functionName == "" {
		return nil, fmt.Errorf("GOVERNANCE_FUNCTION_NAME environment variable not set")
	}

	return &GovernanceClient{
		lambdaClient: lambda.New(sess),
		logger:       logger,
		functionName: functionName,
	}, nil
}

func (c *GovernanceClient) CheckPermission(req GovernanceRequest, correlationID string) (bool, string, error) {
	payload, err := json.Marshal(req)
	if err != nil {
		return false, "", fmt.Errorf("failed to marshal request: %w", err)
	}

	input := &lambda.InvokeInput{
		FunctionName: aws.String(c.functionName),
		Payload:      payload,
	}

	result, err := c.lambdaClient.Invoke(input)
	if err != nil {
		c.logger.Error().
			Err(err).
			Str("correlation_id", correlationID).
			Str("function_name", c.functionName).
			Msg("governance_lambda_invoke_failed")
		return false, "", fmt.Errorf("failed to invoke governance lambda: %w", err)
	}

	if result.FunctionError != nil {
		c.logger.Error().
			Str("correlation_id", correlationID).
			Str("function_error", *result.FunctionError).
			Msg("governance_lambda_error")
		return false, "", fmt.Errorf("governance lambda error: %s", *result.FunctionError)
	}

	var response GovernanceResponse
	if err := json.Unmarshal(result.Payload, &response); err != nil {
		return false, "", fmt.Errorf("failed to unmarshal response: %w", err)
	}

	c.logger.Info().
		Str("correlation_id", correlationID).
		Bool("allowed", response.Allowed).
		Str("reason", response.Reason).
		Msg("governance_check_completed")

	return response.Allowed, response.Reason, nil
}

