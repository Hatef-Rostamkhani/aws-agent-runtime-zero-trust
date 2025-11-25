package handlers

import (
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"time"

	"axon-service/middleware"
	"axon-service/sigv4"
	"github.com/rs/zerolog"
)

type ReasonResponse struct {
	Message   string    `json:"message"`
	Service   string    `json:"service"`
	Timestamp time.Time `json:"timestamp"`
}

// ReasonHandler handles reasoning requests
func ReasonHandler(logger zerolog.Logger) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		correlationID := middleware.GetCorrelationID(r.Context())

		// Verify SigV4 signature
		if err := verifySigV4(r); err != nil {
			logger.Error().
				Err(err).
				Str("correlation_id", correlationID).
				Msg("SIGV4_ERROR: signature verification failed")
			http.Error(w, "Unauthorized", http.StatusUnauthorized)
			return
		}

		// Propagate correlation ID in response headers
		if correlationID != "" {
			w.Header().Set("X-Correlation-ID", correlationID)
		}

		response := ReasonResponse{
			Message:   "Axon heartbeat OK - SigV4 verified",
			Service:   "axon",
			Timestamp: time.Now(),
		}

		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		json.NewEncoder(w).Encode(response)

		logger.Info().
			Str("correlation_id", correlationID).
			Str("message", response.Message).
			Msg("REASON_SUCCESS: SigV4 verified reasoning completed")
	}
}

func verifySigV4(req *http.Request) error {
	// Get credentials from environment
	accessKey := os.Getenv("AWS_ACCESS_KEY_ID")
	secretKey := os.Getenv("AWS_SECRET_ACCESS_KEY")
	region := os.Getenv("AWS_REGION")
	if region == "" {
		region = "us-east-1"
	}

	if accessKey == "" || secretKey == "" {
		return fmt.Errorf("AWS credentials not configured")
	}

	verifier := sigv4.NewSigV4Verifier(accessKey, secretKey, region, "execute-api")

	if err := verifier.VerifyRequest(req); err != nil {
		return fmt.Errorf("request signature verification failed: %w", err)
	}

	return nil
}

