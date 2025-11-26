package main

import (
	"encoding/json"
	"net/http"
	"os"

	"axon-service/handlers"
	"axon-service/middleware"

	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/aws/session"
	"github.com/aws/aws-sdk-go/service/secretsmanager"
	"github.com/gorilla/mux"
	"github.com/rs/zerolog"
)

type AxonService struct {
	secrets *secretsmanager.SecretsManager
	logger  zerolog.Logger
}

func main() {
	// Initialize structured JSON logger
	logger := zerolog.New(os.Stdout).With().
		Timestamp().
		Str("service", "axon").
		Logger()

	// Initialize AWS session
	region := os.Getenv("AWS_REGION")
	if region == "" {
		region = "us-east-1"
	}

	sess, err := session.NewSession(&aws.Config{
		Region: aws.String(region),
	})
	if err != nil {
		logger.Error().Err(err).Msg("failed to create AWS session")
		os.Exit(1)
	}

	service := &AxonService{
		secrets: secretsmanager.New(sess),
		logger:  logger,
	}

	// Load secrets
	if err := service.loadSecrets(); err != nil {
		logger.Error().Err(err).Msg("failed to load secrets")
		os.Exit(1)
	}

	router := mux.NewRouter()

	// Add middleware
	router.Use(middleware.CorrelationMiddleware)
	router.Use(middleware.LoggingMiddleware(logger))

	// Routes
	router.HandleFunc("/health", handlers.HealthHandler(logger)).Methods("GET")

	// Check if we should skip SigV4 verification for testing
	skipSigV4 := os.Getenv("SKIP_SIGV4") == "true"
	router.HandleFunc("/reason", handlers.ReasonHandlerWithSigV4(logger, !skipSigV4)).Methods("GET")

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	logger.Info().
		Str("port", port).
		Str("region", region).
		Msg("axon_service_starting")

	if err := http.ListenAndServe(":"+port, router); err != nil {
		logger.Error().Err(err).Msg("server_failed")
		os.Exit(1)
	}
}

func (s *AxonService) loadSecrets() error {
	secretID := os.Getenv("AXON_SECRET_ARN")
	if secretID == "" {
		s.logger.Warn().Msg("AXON_SECRET_ARN not set, skipping secret loading")
		return nil
	}

	input := &secretsmanager.GetSecretValueInput{
		SecretId: aws.String(secretID),
	}

	result, err := s.secrets.GetSecretValue(input)
	if err != nil {
		return err
	}

	// Parse and validate secrets
	var secrets map[string]string
	if err := json.Unmarshal([]byte(*result.SecretString), &secrets); err != nil {
		return err
	}

	s.logger.Info().
		Str("secret_id", secretID).
		Int("keys_count", len(secrets)).
		Msg("secrets_loaded")
	return nil
}

