package clients

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"math"
	"net/http"
	"os"
	"time"

	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/aws/session"
	v4 "github.com/aws/aws-sdk-go/aws/signer/v4"
	"github.com/rs/zerolog"
)

type AxonClient struct {
	httpClient *http.Client
	signer     *v4.Signer
	logger     zerolog.Logger
	baseURL    string
	region     string
	circuitBreaker *CircuitBreaker
}

type CircuitBreaker struct {
	failures      int
	lastFailTime  time.Time
	state         string // "closed", "open", "half-open"
	maxFailures   int
	resetTimeout  time.Duration
	mu            chan struct{} // Simple mutex using channel
}

const (
	stateClosed   = "closed"
	stateOpen     = "open"
	stateHalfOpen = "half-open"
)

func NewAxonClient(logger zerolog.Logger) (*AxonClient, error) {
	region := os.Getenv("AWS_REGION")
	if region == "" {
		region = "us-east-1"
	}

	baseURL := os.Getenv("AXON_SERVICE_URL")
	if baseURL == "" {
		baseURL = "http://axon/reason"
	}

	sess, err := session.NewSession(&aws.Config{
		Region: aws.String(region),
	})
	if err != nil {
		return nil, fmt.Errorf("failed to create AWS session: %w", err)
	}

	creds := sess.Config.Credentials
	signer := v4.NewSigner(creds)

	cb := &CircuitBreaker{
		maxFailures:  5,
		resetTimeout: 30 * time.Second,
		state:        stateClosed,
		mu:           make(chan struct{}, 1),
	}
	cb.mu <- struct{}{} // Initialize mutex

	return &AxonClient{
		httpClient: &http.Client{
			Timeout: 30 * time.Second,
		},
		signer:         signer,
		logger:         logger,
		baseURL:        baseURL,
		region:         region,
		circuitBreaker: cb,
	}, nil
}

func (c *AxonClient) CallReason(ctx context.Context, correlationID string) (string, error) {
	// Check circuit breaker
	if !c.circuitBreaker.Allow() {
		return "", fmt.Errorf("circuit breaker is open")
	}

	// Retry logic with exponential backoff
	maxRetries := 3
	var lastErr error

	for attempt := 0; attempt < maxRetries; attempt++ {
		if attempt > 0 {
			backoff := time.Duration(math.Pow(2, float64(attempt-1))) * 100 * time.Millisecond
			c.logger.Info().
				Str("correlation_id", correlationID).
				Int("attempt", attempt+1).
				Dur("backoff", backoff).
				Msg("retrying_axon_call")
			time.Sleep(backoff)
		}

		result, err := c.callAxonOnce(ctx, correlationID)
		if err == nil {
			c.circuitBreaker.OnSuccess()
			return result, nil
		}

		lastErr = err
		c.circuitBreaker.OnFailure()

		c.logger.Warn().
			Err(err).
			Str("correlation_id", correlationID).
			Int("attempt", attempt+1).
			Msg("axon_call_failed")
	}

	return "", fmt.Errorf("axon call failed after %d attempts: %w", maxRetries, lastErr)
}

func (c *AxonClient) callAxonOnce(ctx context.Context, correlationID string) (string, error) {
	req, err := http.NewRequestWithContext(ctx, "GET", c.baseURL, nil)
	if err != nil {
		return "", fmt.Errorf("failed to create request: %w", err)
	}

	// Add correlation ID
	req.Header.Set("X-Correlation-ID", correlationID)

	// Sign request with SigV4
	// For GET requests, body is nil
	signBody := bytes.NewReader([]byte{})
	_, err = c.signer.Sign(req, signBody, "execute-api", c.region, time.Now())
	if err != nil {
		return "", fmt.Errorf("failed to sign request: %w", err)
	}

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return "", fmt.Errorf("request failed: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return "", fmt.Errorf("axon returned status %d", resp.StatusCode)
	}

	bodyBytes, err := io.ReadAll(resp.Body)
	if err != nil {
		return "", fmt.Errorf("failed to read response: %w", err)
	}

	var axonResp map[string]interface{}
	if err := json.Unmarshal(bodyBytes, &axonResp); err != nil {
		return "", fmt.Errorf("failed to unmarshal response: %w", err)
	}

	if message, ok := axonResp["message"].(string); ok {
		return message, nil
	}

	return "Axon response received", nil
}

// CircuitBreaker methods
func (cb *CircuitBreaker) Allow() bool {
	<-cb.mu // Lock
	defer func() { cb.mu <- struct{}{} }() // Unlock

	if cb.state == stateClosed {
		return true
	}

	if cb.state == stateOpen {
		if time.Since(cb.lastFailTime) > cb.resetTimeout {
			cb.state = stateHalfOpen
			return true
		}
		return false
	}

	// Half-open state
	return true
}

func (cb *CircuitBreaker) OnSuccess() {
	<-cb.mu // Lock
	defer func() { cb.mu <- struct{}{} }() // Unlock

	cb.failures = 0
	if cb.state == stateHalfOpen {
		cb.state = stateClosed
	}
}

func (cb *CircuitBreaker) OnFailure() {
	<-cb.mu // Lock
	defer func() { cb.mu <- struct{}{} }() // Unlock

	cb.failures++
	cb.lastFailTime = time.Now()

	if cb.failures >= cb.maxFailures {
		cb.state = stateOpen
	}
}

