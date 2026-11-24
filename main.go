package main

import (
	"context"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	zip_streamer "github.com/scosman/zipstreamer/zip_streamer"
)

// version is set at build time via -ldflags "-X main.version=..."
var version = "dev"

func main() {
	zipServer := zip_streamer.NewServer()
	zipServer.Compression = (os.Getenv("ZS_COMPRESSION") == "DEFLATE")
	zipServer.ListfileUrlPrefix = os.Getenv("ZS_LISTFILE_URL_PREFIX")

	port := os.Getenv("PORT")
	if port == "" {
		port = "4008"
	}

	httpServer := &http.Server{
		Addr:        ":" + port,
		Handler:     zipServer,
		ReadTimeout: 10 * time.Second,
	}

	// Closed when the server stops on its own (e.g. port already in use)
	serverStopped := make(chan struct{})
	go func() {
		log.Printf("ZipStreamer %s starting on port %s", version, port)
		err := httpServer.ListenAndServe()
		if err != nil && err != http.ErrServerClosed {
			log.Printf("Server Error: %s", err)
		}
		close(serverStopped)
	}()

	// Listen for os signal for graceful shutdown
	shutdownChannel := make(chan os.Signal, 10)
	signal.Notify(shutdownChannel, syscall.SIGTERM, syscall.SIGINT, syscall.SIGQUIT)

	// Wait for shutdown signal, then shut down
	select {
	case shutdownSignal := <-shutdownChannel:
		log.Printf("Received signal (%s), shutting down...", shutdownSignal.String())
		httpServer.Shutdown(context.Background())
	case <-serverStopped:
		// Exit was not expected, return non 0 exit code
		log.Printf("Server stopped unexpectedly, shutting down...")
		os.Exit(1)
	}
}
