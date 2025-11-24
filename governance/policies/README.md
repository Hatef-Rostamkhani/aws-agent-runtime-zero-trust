# Governance Policies

This directory contains governance policy definitions and schema.

## Files

- `default.json` - Default policies for the system
- `schema.json` - JSON schema for policy validation
- `README.md` - This file

## Policy Structure

A policy defines access control rules for a service-intent combination:

```json
{
  "service": "orbit",
  "intent": "call_reasoning",
  "enabled": true,
  "description": "Allow Orbit to call Axon reasoning service",
  "time_restrictions": {
    "allowed_hours": [0, 1, 2, ..., 23]
  },
  "rate_limits": {
    "requests_per_minute": 100,
    "requests_per_hour": 1000
  },
  "conditions": []
}
```

### Fields

- **service** (required): The service making the request (e.g., "orbit")
- **intent** (required): The intent or action being requested (e.g., "call_reasoning")
- **enabled** (required): Whether this policy is active (boolean)
- **description**: Human-readable description of the policy
- **time_restrictions**: Optional time-based restrictions
  - **allowed_hours**: Array of hours (0-23) when requests are allowed
- **rate_limits**: Optional rate limiting configuration
  - **requests_per_minute**: Maximum requests per minute
  - **requests_per_hour**: Maximum requests per hour
- **conditions**: Array of custom conditions to evaluate
  - **type**: Condition type (e.g., "context_check")
  - **field**: Field name from request context
  - **operator**: Comparison operator (equals, not_equals, contains, greater_than, less_than)
  - **value**: Expected value
  - **description**: Human-readable description

## Default Policies

### orbit:call_reasoning
Allows Orbit service to call Axon reasoning service. No time restrictions, rate limit of 100/min and 1000/hour.

### orbit:call_metrics
Allows Orbit service to retrieve metrics. No time restrictions, rate limit of 60/min and 500/hour.

### admin:manage_policies
Allows admin to manage governance policies. No time restrictions, rate limit of 10/min and 100/hour.

## Loading Policies

Policies are automatically loaded via Terraform when the DynamoDB table is created. To manually load policies:

```bash
export POLICY_TABLE_NAME=agent-runtime-governance-policies
python scripts/load-policies.py
```

## Policy Evaluation

Policies are evaluated in the following order:

1. Check if policy exists
2. Check if policy is enabled
3. Check time restrictions (if configured)
4. Check rate limits (if configured)
5. Evaluate custom conditions (if any)

If any check fails, the request is denied with an appropriate reason.

