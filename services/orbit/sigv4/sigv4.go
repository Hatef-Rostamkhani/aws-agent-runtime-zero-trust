package sigv4

import (
	"bytes"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"io"
	"net/http"
	"sort"
	"strings"
	"time"

	"github.com/aws/aws-sdk-go/aws/credentials"
	"github.com/aws/aws-sdk-go/aws/signer/v4"
)

type SigV4Signer struct {
	credentials *credentials.Credentials
	region      string
	service     string
}

func NewSigV4Signer(accessKey, secretKey, region, service string) *SigV4Signer {
	creds := credentials.NewStaticCredentials(accessKey, secretKey, "")
	return &SigV4Signer{
		credentials: creds,
		region:      region,
		service:     service,
	}
}

func (s *SigV4Signer) SignRequest(req *http.Request, body []byte) error {
	signer := v4.NewSigner(s.credentials)

	var bodyReader io.ReadSeeker
	if body != nil {
		bodyReader = bytes.NewReader(body)
	}

	_, err := signer.Sign(req, bodyReader, s.service, s.region, time.Now())
	return err
}

// Verify signature (for receiving service)
func (s *SigV4Signer) VerifyRequest(req *http.Request) error {
	// Extract signature components from headers
	authHeader := req.Header.Get("Authorization")
	if authHeader == "" {
		return fmt.Errorf("missing Authorization header")
	}

	// Parse Authorization header
	// Format: AWS4-HMAC-SHA256 Credential=AKIAIOSFODNN7EXAMPLE/20130524/us-east-1/s3/aws4_request, SignedHeaders=host;range;x-amz-date, Signature=example-signature

	parts := strings.Split(authHeader, " ")
	if len(parts) < 4 {
		return fmt.Errorf("invalid Authorization header format")
	}

	// Extract credential scope
	credentialPart := strings.TrimPrefix(parts[1], "Credential=")
	credParts := strings.Split(credentialPart, "/")
	if len(credParts) < 5 {
		return fmt.Errorf("invalid credential scope")
	}

	requestRegion := credParts[2]
	requestService := credParts[3]

	if requestRegion != s.region || requestService != s.service {
		return fmt.Errorf("signature region/service mismatch")
	}

	// For full verification, we would need to reconstruct the canonical request
	// and verify the signature. This is a simplified version.
	// In production, use AWS SDK's verification or implement full SigV4 verification.

	return nil
}

func (s *SigV4Signer) getCanonicalRequest(req *http.Request, body []byte) string {
	// HTTPRequestMethod
	canonical := req.Method + "\n"

	// CanonicalURI
	canonical += req.URL.Path + "\n"

	// CanonicalQueryString
	queryParams := req.URL.Query()
	if len(queryParams) > 0 {
		keys := make([]string, 0, len(queryParams))
		for k := range queryParams {
			keys = append(keys, k)
		}
		sort.Strings(keys)

		for i, key := range keys {
			if i > 0 {
				canonical += "&"
			}
			canonical += key + "=" + queryParams[key][0]
		}
	}
	canonical += "\n"

	// CanonicalHeaders
	headers := make(map[string]string)
	for key, values := range req.Header {
		headers[strings.ToLower(key)] = values[0]
	}

	// Add host header if not present
	if _, ok := headers["host"]; !ok {
		headers["host"] = req.Host
	}

	var headerKeys []string
	for key := range headers {
		headerKeys = append(headerKeys, key)
	}
	sort.Strings(headerKeys)

	signedHeaders := strings.Join(headerKeys, ";")

	for _, key := range headerKeys {
		canonical += key + ":" + headers[key] + "\n"
	}
	canonical += "\n"

	canonical += signedHeaders + "\n"

	// HashedPayload
	var payload []byte
	if body != nil {
		payload = body
	} else {
		payload = []byte("")
	}

	hash := sha256.Sum256(payload)
	canonical += hex.EncodeToString(hash[:])

	return canonical
}
