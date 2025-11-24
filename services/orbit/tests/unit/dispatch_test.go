package unit

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"testing"

	"orbit-service/clients"
	"orbit-service/handlers"
	"orbit-service/middleware"
	"github.com/rs/zerolog"
)

// MockGovernanceClient is a mock implementation of GovernanceClient
type MockGovernanceClient struct {
	allowed bool
	reason  string
	err     error
}

func (m *MockGovernanceClient) CheckPermission(req clients.GovernanceRequest, correlationID string) (bool, string, error) {
	if m.err != nil {
		return false, "", m.err
	}
	return m.allowed, m.reason, nil
}

// MockAxonClient is a mock implementation of AxonClient
type MockAxonClient struct {
	response string
	err      error
}

func (m *MockAxonClient) CallReason(ctx context.Context, correlationID string) (string, error) {
	if m.err != nil {
		return "", m.err
	}
	return m.response, nil
}

func TestDispatchHandlerSuccess(t *testing.T) {
	logger := zerolog.Nop()
	governanceClient := &MockGovernanceClient{allowed: true}
	axonClient := &MockAxonClient{response: "Axon heartbeat OK"}

	handler := handlers.DispatchHandler(logger, governanceClient, axonClient)

	req, err := http.NewRequest("POST", "/dispatch", nil)
	if err != nil {
		t.Fatal(err)
	}

	ctx := context.WithValue(req.Context(), middleware.CorrelationIDKey, "test-correlation-id")
	req = req.WithContext(ctx)

	rr := httptest.NewRecorder()
	handler.ServeHTTP(rr, req)

	if status := rr.Code; status != http.StatusOK {
		t.Errorf("Dispatch handler returned wrong status code: got %v want %v", status, http.StatusOK)
	}

	var response handlers.DispatchResponse
	if err := json.NewDecoder(rr.Body).Decode(&response); err != nil {
		t.Fatalf("Failed to decode response: %v", err)
	}

	if response.Status != "success" {
		t.Errorf("Dispatch handler returned wrong status: got %v want success", response.Status)
	}

	if response.Message != "Axon heartbeat OK" {
		t.Errorf("Dispatch handler returned wrong message: got %v want 'Axon heartbeat OK'", response.Message)
	}
}

func TestDispatchHandlerGovernanceDenied(t *testing.T) {
	logger := zerolog.Nop()
	governanceClient := &MockGovernanceClient{
		allowed: false,
		reason:  "Policy violation",
	}
	axonClient := &MockAxonClient{}

	handler := handlers.DispatchHandler(logger, governanceClient, axonClient)

	req, err := http.NewRequest("POST", "/dispatch", nil)
	if err != nil {
		t.Fatal(err)
	}

	ctx := context.WithValue(req.Context(), middleware.CorrelationIDKey, "test-correlation-id")
	req = req.WithContext(ctx)

	rr := httptest.NewRecorder()
	handler.ServeHTTP(rr, req)

	if status := rr.Code; status != http.StatusForbidden {
		t.Errorf("Dispatch handler should return 403 when governance denies: got %v want %v", status, http.StatusForbidden)
	}

	var response handlers.DispatchResponse
	if err := json.NewDecoder(rr.Body).Decode(&response); err != nil {
		t.Fatalf("Failed to decode response: %v", err)
	}

	if response.Status != "denied" {
		t.Errorf("Dispatch handler returned wrong status: got %v want denied", response.Status)
	}

	if response.Reason != "Policy violation" {
		t.Errorf("Dispatch handler returned wrong reason: got %v want 'Policy violation'", response.Reason)
	}
}

func TestDispatchHandlerGovernanceError(t *testing.T) {
	logger := zerolog.Nop()
	governanceClient := &MockGovernanceClient{
		err: errors.New("Lambda invocation failed"),
	}
	axonClient := &MockAxonClient{}

	handler := handlers.DispatchHandler(logger, governanceClient, axonClient)

	req, err := http.NewRequest("POST", "/dispatch", nil)
	if err != nil {
		t.Fatal(err)
	}

	ctx := context.WithValue(req.Context(), middleware.CorrelationIDKey, "test-correlation-id")
	req = req.WithContext(ctx)

	rr := httptest.NewRecorder()
	handler.ServeHTTP(rr, req)

	if status := rr.Code; status != http.StatusInternalServerError {
		t.Errorf("Dispatch handler should return 500 on governance error: got %v want %v", status, http.StatusInternalServerError)
	}
}

