package handlers

import (
	"encoding/json"
	"net/http"
	"time"

	"orbit-service/middleware"
	"github.com/rs/zerolog"
)

type HealthResponse struct {
	Status    string    `json:"status"`
	Service   string    `json:"service"`
	Timestamp time.Time `json:"timestamp"`
}

// HealthHandler handles health check requests
func HealthHandler(logger zerolog.Logger) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		correlationID := middleware.GetCorrelationID(r.Context())

		response := HealthResponse{
			Status:    "healthy",
			Service:   "orbit",
			Timestamp: time.Now(),
		}

		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		json.NewEncoder(w).Encode(response)

		logger.Info().
			Str("correlation_id", correlationID).
			Str("status", "healthy").
			Msg("health_check")
	}
}

