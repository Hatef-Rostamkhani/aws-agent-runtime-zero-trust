package unit

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"axon-service/handlers"
	"axon-service/middleware"
	"github.com/rs/zerolog"
)

func TestHealthHandler(t *testing.T) {
	logger := zerolog.Nop()
	handler := handlers.HealthHandler(logger)

	req, err := http.NewRequest("GET", "/health", nil)
	if err != nil {
		t.Fatal(err)
	}

	// Add correlation ID to context
	ctx := context.WithValue(req.Context(), middleware.CorrelationIDKey, "test-correlation-id")
	req = req.WithContext(ctx)

	rr := httptest.NewRecorder()
	handler.ServeHTTP(rr, req)

	if status := rr.Code; status != http.StatusOK {
		t.Errorf("Health handler returned wrong status code: got %v want %v", status, http.StatusOK)
	}

	var response handlers.HealthResponse
	if err := json.NewDecoder(rr.Body).Decode(&response); err != nil {
		t.Fatalf("Failed to decode response: %v", err)
	}

	if response.Status != "healthy" {
		t.Errorf("Health handler returned wrong status: got %v want healthy", response.Status)
	}

	if response.Service != "axon" {
		t.Errorf("Health handler returned wrong service: got %v want axon", response.Service)
	}
}

func TestHealthHandlerCorrelationID(t *testing.T) {
	logger := zerolog.Nop()
	handler := handlers.HealthHandler(logger)

	req, err := http.NewRequest("GET", "/health", nil)
	if err != nil {
		t.Fatal(err)
	}

	correlationID := "test-correlation-id"
	req.Header.Set("X-Correlation-ID", correlationID)

	// Add correlation ID to context
	ctx := context.WithValue(req.Context(), middleware.CorrelationIDKey, correlationID)
	req = req.WithContext(ctx)

	rr := httptest.NewRecorder()
	handler.ServeHTTP(rr, req)

	if correlationIDHeader := rr.Header().Get("X-Correlation-ID"); correlationIDHeader != correlationID {
		t.Errorf("Correlation ID not propagated: got %v want %v", correlationIDHeader, correlationID)
	}
}

