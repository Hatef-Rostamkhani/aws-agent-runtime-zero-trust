package handlers

import (
	"encoding/json"
	"net/http"
	"time"

	"axon-service/middleware"
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

		response := ReasonResponse{
			Message:   "Axon heartbeat OK",
			Service:   "axon",
			Timestamp: time.Now(),
		}

		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		json.NewEncoder(w).Encode(response)

		logger.Info().
			Str("correlation_id", correlationID).
			Str("message", response.Message).
			Msg("reasoning_completed")
	}
}

