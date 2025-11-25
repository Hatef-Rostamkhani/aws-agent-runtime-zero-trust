# SigV4 Request Signing Implementation

## Overview

This document describes the AWS Signature Version 4 (SigV4) implementation for securing inter-service communication in the AWS Agent Runtime.

## SigV4 Flow

### Request Signing Process

1. **Canonical Request Creation**: Construct a standardized version of the HTTP request
2. **String to Sign**: Create a string that includes the canonical request and signing metadata
3. **Signing Key Derivation**: Derive a signing key from the secret access key
4. **Signature Calculation**: Use HMAC-SHA256 to create the final signature
5. **Authorization Header**: Add the signature to the request

### Canonical Request Format

```
HTTPRequestMethod
CanonicalURI
CanonicalQueryString
CanonicalHeaders

SignedHeaders
HashedPayload
```

### Authorization Header Format

```
AWS4-HMAC-SHA256 Credential=AKIAIOSFODNN7EXAMPLE/20130524/us-east-1/s3/aws4_request, SignedHeaders=host;range;x-amz-date, Signature=example-signature
```

## Implementation Details

### Orbit Service (Client)

The Orbit service signs outgoing requests to the Axon service using SigV4. The implementation includes:

- **SigV4Signer**: Core signing functionality
- **AxonClient**: HTTP client with automatic request signing
- **Integration**: Seamless integration with existing service communication

### Axon Service (Server)

The Axon service verifies incoming SigV4 signatures to ensure request authenticity:

- **SigV4Verifier**: Signature verification logic
- **Request Validation**: Pre-handler signature checking
- **Error Handling**: Proper rejection of unsigned or invalid requests

## Security Benefits

### Authentication
- Proves request originates from legitimate service
- Prevents replay attacks with timestamp validation
- Service-specific credential isolation

### Integrity
- Ensures request hasn't been modified in transit
- Protects against man-in-the-middle attacks
- Validates all critical request components

### Non-Repudiation
- Sender cannot deny having made the request
- Audit trail for all inter-service communication

## Configuration

### Required Parameters
- **Access Key**: Service-specific IAM access key
- **Secret Key**: Corresponding secret access key
- **Region**: AWS region for the request
- **Service**: Target service name (e.g., "execute-api")

### Environment Variables
```bash
ORBIT_AWS_ACCESS_KEY=AKIA...
ORBIT_AWS_SECRET_KEY=...
AXON_AWS_ACCESS_KEY=AKIA...
AXON_AWS_SECRET_KEY=...
AWS_REGION=us-east-1
```

## Testing

### Unit Tests
- Canonical request generation
- Signature calculation
- Verification logic
- Error handling scenarios

### Integration Tests
- End-to-end signed communication
- Signature rejection for unsigned requests
- Cross-service authentication

### Validation Scripts
- Automated SigV4 compliance checking
- Performance impact assessment
- Security validation

## Performance Considerations

### Overhead
- ~1-2ms additional latency per request
- Minimal CPU overhead for signing/verification
- No impact on request payload size

### Optimization
- Reuse signer instances across requests
- Cache derived signing keys when possible
- Batch verification for high-throughput scenarios

## Troubleshooting

### Common Issues

1. **Clock Skew**: Ensure system clocks are synchronized
2. **Region Mismatch**: Verify region configuration matches
3. **Credential Issues**: Confirm access keys are valid and active
4. **Header Ordering**: Signed headers must match exactly

### Debugging
- Enable detailed logging for signature components
- Use AWS CLI signature verification for testing
- Validate canonical request construction

## Compliance

### AWS Standards
- Fully compatible with AWS SigV4 specification
- Supports all standard AWS services
- Maintains security properties of AWS authentication

### Security Best Practices
- Rotate access keys regularly
- Use IAM roles with temporary credentials
- Implement proper key management
- Monitor for signature failures
