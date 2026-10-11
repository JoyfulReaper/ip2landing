package main

import (
	"embed"
	"io/fs"
	"log"
	"net/http"
	"os"
	"time"
)

//go:embed static/*
var staticFiles embed.FS

func main() {
	listenAddress := os.Getenv("I2PLANDING_LISTEN_ADDRESS")
	if listenAddress == "" {
		listenAddress = "127.0.0.1:5183"
	}

	staticFS, err := fs.Sub(staticFiles, "static")
	if err != nil {
		log.Fatal(err)
	}

	mux := http.NewServeMux()

	mux.HandleFunc("/healthz", func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodGet {
			http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
			return
		}

		w.Header().Set("Content-Type", "text/plain; charset=utf-8")
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte("ok\n"))
	})

	mux.Handle("/", http.FileServer(http.FS(staticFS)))

	server := &http.Server{
		Addr:              listenAddress,
		Handler:           mux,
		ReadHeaderTimeout: 5 * time.Second,
	}

	log.Printf("I2P landing listening on http://%s", listenAddress)
	log.Fatal(server.ListenAndServe())
}
