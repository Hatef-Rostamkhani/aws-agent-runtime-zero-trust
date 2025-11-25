package sigv4

import (
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"net/http"
	"sort"
	"strings"
	"time"

	"github.com/aws/aws-sdk-go/aws/credentials"
)

type SigV4Verifier struct {
	credentials *credentials.Credentials
	region      string
	service     string
}

func NewSigV4Verifier(accessKey, secretKey, region, service string) *SigV4Verifier {
	creds := credentials.NewStaticCredentials(accessKey, secretKey, "")
	return &SigV4Verifier{
		credentials: creds,
		region:      region,
		service:     service,
	}
}

// VerifyRequest verifies the SigV4 signature of an incoming request
func (v *SigV4Verifier) VerifyRequest(req *http.Request) error {
	// Extract Authorization header
	authHeader := req.Header.Get("Authorization")
	if authHeader == "" {
		return fmt.Errorf("missing Authorization header")
	}

	// Parse the Authorization header
	// Format: AWS4-HMAC-SHA256 Credential=AKIAIOSFODNN7EXAMPLE/20130524/us-east-1/execute-api/aws4_request, SignedHeaders=host;x-amz-date, Signature=example-signature
	parts := strings.Split(authHeader, " ")
	if len(parts) < 4 || !strings.HasPrefix(parts[0], "AWS4-HMAC-SHA256") {
		return fmt.Errorf("invalid Authorization header format")
	}

	// Extract credential scope
	credentialPart := strings.TrimPrefix(parts[1], "Credential=")
	credParts := strings.Split(credentialPart, "/")
	if len(credParts) < 5 {
		return fmt.Errorf("invalid credential scope")
	}

	date := credParts[1]
	requestRegion := credParts[2]
	requestService := credParts[3]

	// Validate region and service
	if requestRegion != v.region || requestService != v.service {
		return fmt.Errorf("signature region/service mismatch: got %s/%s, expected %s/%s",
			requestRegion, requestService, v.region, v.service)
	}

	// Extract signed headers
	signedHeadersPart := strings.TrimPrefix(parts[2], "SignedHeaders=")
	signedHeaders := strings.Split(signedHeadersPart, ";")

	// Extract signature
	signaturePart := strings.TrimPrefix(parts[3], "Signature=")
	requestSignature := signaturePart

	// Get the date for key derivation
	if !strings.HasSuffix(date, "T000000Z") {
		// If it's not in the expected format, try to parse it
		if t, err := time.Parse("20060102", date); err == nil {
			date = t.Format("20060102")
		}
	}

	// Reconstruct the canonical request
	canonicalRequest := v.buildCanonicalRequest(req, signedHeaders)

	// Build string to sign
	stringToSign := v.buildStringToSign(canonicalRequest, date, requestRegion, requestService)

	// Derive signing key
	signingKey := v.deriveSigningKey(date, requestRegion, requestService)

	// Calculate expected signature
	expectedSignature := v.calculateSignature(stringToSign, signingKey)

	// Compare signatures
	if !hmac.Equal([]byte(expectedSignature), []byte(requestSignature)) {
		return fmt.Errorf("signature verification failed")
	}

	return nil
}

func (v *SigV4Verifier) buildCanonicalRequest(req *http.Request, signedHeaders []string) string {
	var canonical strings.Builder

	// HTTPRequestMethod
	canonical.WriteString(req.Method)
	canonical.WriteString("\n")

	// CanonicalURI
	canonical.WriteString(req.URL.EscapedPath())
	canonical.WriteString("\n")

	// CanonicalQueryString
	query := req.URL.Query()
	if len(query) > 0 {
		var queryParts []string
		for key, values := range query {
			for _, value := range values {
				queryParts = append(queryParts, key+"="+value)
			}
		}
		sort.Strings(queryParts)
		canonical.WriteString(strings.Join(queryParts, "&"))
	}
	canonical.WriteString("\n")

	// CanonicalHeaders
	headers := make(map[string]string)
	for key, values := range req.Header {
		headers[strings.ToLower(key)] = strings.TrimSpace(values[0])
	}

	// Ensure host header is present
	if _, ok := headers["host"]; !ok {
		headers["host"] = req.Host
	}

	for _, header := range signedHeaders {
		if value, ok := headers[header]; ok {
			canonical.WriteString(header)
			canonical.WriteString(":")
			canonical.WriteString(value)
			canonical.WriteString("\n")
		}
	}
	canonical.WriteString("\n")

	// SignedHeaders
	canonical.WriteString(strings.Join(signedHeaders, ";"))
	canonical.WriteString("\n")

	// HashedPayload
	bodyHash := req.Header.Get("x-amz-content-sha256")
	if bodyHash == "" {
		bodyHash = "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
	}
	canonical.WriteString(bodyHash)

	return canonical.String()
}

func (v *SigV4Verifier) buildStringToSign(canonicalRequest, date, region, service string) string {
	var stringToSign strings.Builder

	stringToSign.WriteString("AWS4-HMAC-SHA256")
	stringToSign.WriteString("\n")

	// Time stamp (we'll use the date from credential scope)
	stringToSign.WriteString(date)
	stringToSign.WriteString("T000000Z")
	stringToSign.WriteString("\n")

	// Credential scope
	stringToSign.WriteString(date)
	stringToSign.WriteString("/")
	stringToSign.WriteString(region)
	stringToSign.WriteString("/")
	stringToSign.WriteString(service)
	stringToSign.WriteString("/aws4_request")
	stringToSign.WriteString("\n")

	// Hash of canonical request
	hash := sha256.Sum256([]byte(canonicalRequest))
	stringToSign.WriteString(hex.EncodeToString(hash[:]))

	return stringToSign.String()
}

func (v *SigV4Verifier) deriveSigningKey(date, region, service string) []byte {
	// Get credentials
	creds, err := v.credentials.Get()
	if err != nil {
		return nil
	}

	// kDate = HMAC("AWS4" + secret_key, date)
	kDate := hmacSHA256([]byte("AWS4"+creds.SecretAccessKey), []byte(date))

	// kRegion = HMAC(kDate, region)
	kRegion := hmacSHA256(kDate, []byte(region))

	// kService = HMAC(kRegion, service)
	kService := hmacSHA256(kRegion, []byte(service))

	// kSigning = HMAC(kService, "aws4_request")
	kSigning := hmacSHA256(kService, []byte("aws4_request"))

	return kSigning
}

func (v *SigV4Verifier) calculateSignature(stringToSign string, signingKey []byte) string {
	signature := hmacSHA256(signingKey, []byte(stringToSign))
	return hex.EncodeToString(signature)
}

func hmacSHA256(key, data []byte) []byte {
	h := hmac.New(sha256.New, key)
	h.Write(data)
	return h.Sum(nil)
}
