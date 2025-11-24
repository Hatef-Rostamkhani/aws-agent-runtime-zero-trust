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

func TestReasonHandler(t *testing.T) {
	logger := zerolog.Nop()
	handler := handlers.ReasonHandler(logger)

	req, err := http.NewRequest("GET", "/reason", nil)
	if err != nil {
		t.Fatal(err)
	}

	// Add correlation ID to context
	ctx := context.WithValue(req.Context(), middleware.CorrelationIDKey, "test-correlation-id")
	req = req.WithContext(ctx)

	rr := httptest.NewRecorder()
	handler.ServeHTTP(rr, req)

	if status := rr.Code; status != http.StatusOK {
		t.Errorf("Reason handler returned wrong status code: got %v want %v", status, http.StatusOK)
	}

	var response handlers.ReasonResponse
	if err := json.NewDecoder(rr.Body).Decode(&response); err != nil {
		t.Fatalf("Failed to decode response: %v", err)
	}

	if response.Message != "Axon heartbeat OK" {
		t.Errorf("Reason handler returned wrong message: got %v want 'Axon heartbeat OK'", response.Message)
	}

	if response.Service != "axon" {
		t.Errorf("Reason handler returned wrong service: got %v want axon", response.Service)
	}
}

