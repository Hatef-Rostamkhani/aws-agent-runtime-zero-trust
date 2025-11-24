package main

import (
	"net/http"
	"os"

	"orbit-service/clients"
	"orbit-service/handlers"
	"orbit-service/middleware"

	"github.com/gorilla/mux"
	"github.com/rs/zerolog"
)

func main() {
	// Initialize structured JSON logger
	logger := zerolog.New(os.Stdout).With().
		Timestamp().
		Str("service", "orbit").
		Logger()

	// Initialize clients
	governanceClient, err := clients.NewGovernanceClient(logger)
	if err != nil {
		logger.Error().Err(err).Msg("failed to create governance client")
		os.Exit(1)
	}

	axonClient, err := clients.NewAxonClient(logger)
	if err != nil {
		logger.Error().Err(err).Msg("failed to create axon client")
		os.Exit(1)
	}

	router := mux.NewRouter()

	// Add middleware
	router.Use(middleware.CorrelationMiddleware)
	router.Use(middleware.LoggingMiddleware(logger))

	// Routes
	router.HandleFunc("/health", handlers.HealthHandler(logger)).Methods("GET")
	router.HandleFunc("/dispatch", handlers.DispatchHandler(logger, governanceClient, axonClient)).Methods("POST")

	port := os.Getenv("PORT")
	if port == "" {
		port = "80"
	}

	logger.Info().
		Str("port", port).
		Msg("orbit_service_starting")

	if err := http.ListenAndServe(":"+port, router); err != nil {
		logger.Error().Err(err).Msg("server_failed")
		os.Exit(1)
	}
}

