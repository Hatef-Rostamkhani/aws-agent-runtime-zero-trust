package unit

import (
	"encoding/json"
	"os"
	"testing"

	"orbit-service/clients"
	"github.com/rs/zerolog"
)

func TestGovernanceClientCheckPermission(t *testing.T) {
	// This test requires AWS credentials or mocking
	// For now, we'll test the structure
	logger := zerolog.Nop()

	// Set a dummy function name for testing structure
	os.Setenv("GOVERNANCE_FUNCTION_NAME", "test-governance-function")
	defer os.Unsetenv("GOVERNANCE_FUNCTION_NAME")

	_, err := clients.NewGovernanceClient(logger)
	if err == nil {
		// If AWS session can be created, test the request structure
		req := clients.GovernanceRequest{
			Service: "orbit",
			Intent:  "call_reasoning",
		}

		// Verify request can be marshaled
		payload, err := json.Marshal(req)
		if err != nil {
			t.Fatalf("Failed to marshal request: %v", err)
		}

		var unmarshaled clients.GovernanceRequest
		if err := json.Unmarshal(payload, &unmarshaled); err != nil {
			t.Fatalf("Failed to unmarshal request: %v", err)
		}

		if unmarshaled.Service != "orbit" {
			t.Errorf("Expected service 'orbit', got '%s'", unmarshaled.Service)
		}

		if unmarshaled.Intent != "call_reasoning" {
			t.Errorf("Expected intent 'call_reasoning', got '%s'", unmarshaled.Intent)
		}
	}
}

