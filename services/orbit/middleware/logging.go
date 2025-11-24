package middleware

import (
	"net/http"
	"time"

	"github.com/rs/zerolog"
)

// LoggingMiddleware logs HTTP requests with structured JSON logging
func LoggingMiddleware(logger zerolog.Logger) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			start := time.Now()

			correlationID := GetCorrelationID(r.Context())

			// Log request
			logger.Info().
				Str("correlation_id", correlationID).
				Str("method", r.Method).
				Str("path", r.URL.Path).
				Str("remote_addr", r.RemoteAddr).
				Msg("request")

			// Wrap response writer to capture status code
			wrapped := &responseWriter{ResponseWriter: w, statusCode: http.StatusOK}

			next.ServeHTTP(wrapped, r)

			// Log response
			duration := time.Since(start)
			logger.Info().
				Str("correlation_id", correlationID).
				Str("method", r.Method).
				Str("path", r.URL.Path).
				Int("status_code", wrapped.statusCode).
				Int64("duration_ms", duration.Milliseconds()).
				Msg("response")
		})
	}
}

type responseWriter struct {
	http.ResponseWriter
	statusCode int
}

func (rw *responseWriter) WriteHeader(code int) {
	rw.statusCode = code
	rw.ResponseWriter.WriteHeader(code)
}

