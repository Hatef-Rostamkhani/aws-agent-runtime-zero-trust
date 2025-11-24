package handlers

import (
	"encoding/json"
	"net/http"
	"time"

	"orbit-service/clients"
	"orbit-service/middleware"
	"github.com/rs/zerolog"
)

type DispatchResponse struct {
	Status    string    `json:"status"`
	Message   string    `json:"message,omitempty"`
	Reason    string    `json:"reason,omitempty"`
	Timestamp time.Time `json:"timestamp"`
}

// DispatchHandler handles dispatch requests
func DispatchHandler(logger zerolog.Logger, governanceClient *clients.GovernanceClient, axonClient *clients.AxonClient) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		correlationID := middleware.GetCorrelationID(r.Context())

		// Step 1: Check governance
		governanceReq := clients.GovernanceRequest{
			Service: "orbit",
			Intent:  "call_reasoning",
		}

		allowed, reason, err := governanceClient.CheckPermission(governanceReq, correlationID)
		if err != nil {
			logger.Error().
				Err(err).
				Str("correlation_id", correlationID).
				Msg("governance_check_failed")

			response := DispatchResponse{
				Status:    "error",
				Reason:    "Governance check failed",
				Timestamp: time.Now(),
			}
			w.Header().Set("Content-Type", "application/json")
			w.WriteHeader(http.StatusInternalServerError)
			json.NewEncoder(w).Encode(response)
			return
		}

		if !allowed {
			logger.Warn().
				Str("correlation_id", correlationID).
				Str("reason", reason).
				Msg("governance_denied")

			response := DispatchResponse{
				Status:    "denied",
				Reason:    reason,
				Timestamp: time.Now(),
			}
			w.Header().Set("Content-Type", "application/json")
			w.WriteHeader(http.StatusForbidden)
			json.NewEncoder(w).Encode(response)
			return
		}

		// Step 2: Call Axon service
		axonResponse, err := axonClient.CallReason(r.Context(), correlationID)
		if err != nil {
			logger.Error().
				Err(err).
				Str("correlation_id", correlationID).
				Msg("axon_call_failed")

			response := DispatchResponse{
				Status:    "error",
				Reason:    "Failed to call Axon service",
				Timestamp: time.Now(),
			}
			w.Header().Set("Content-Type", "application/json")
			w.WriteHeader(http.StatusInternalServerError)
			json.NewEncoder(w).Encode(response)
			return
		}

		// Step 3: Return successful response
		response := DispatchResponse{
			Status:    "success",
			Message:   axonResponse,
			Timestamp: time.Now(),
		}

		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		json.NewEncoder(w).Encode(response)

		logger.Info().
			Str("correlation_id", correlationID).
			Str("status", "success").
			Msg("dispatch_completed")
	}
}

