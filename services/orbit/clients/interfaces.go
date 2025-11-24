package clients

import "context"

// GovernanceChecker defines the interface for checking governance permissions
type GovernanceChecker interface {
	CheckPermission(req GovernanceRequest, correlationID string) (bool, string, error)
}

// AxonCaller defines the interface for calling the Axon service
type AxonCaller interface {
	CallReason(ctx context.Context, correlationID string) (string, error)
}

