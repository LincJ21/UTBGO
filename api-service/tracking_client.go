package main

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"time"
)

// TrackingEvent representa el cuerpo de la petición para el tracking-service.
type TrackingEvent struct {
	UserID     int            `json:"user_id"`
	ContentID  int            `json:"content_id"`
	EventType  string         `json:"event_type"`
	EventValue float64        `json:"event_value"`
	Metadata   map[string]any `json:"metadata"`
}

// SendTrackingEvent envía un evento al microservicio de tracking de forma asíncrona.
func SendTrackingEvent(ctx context.Context, token string, event TrackingEvent) {
	trackingURL := os.Getenv("TRACKING_SERVICE_URL")
	if trackingURL == "" {
		return
	}

	// Ejecutar en una goroutine para no bloquear la respuesta al usuario
	go func() {
		url := fmt.Sprintf("%s/api/v1/events", trackingURL)

		jsonData, err := json.Marshal(event)
		if err != nil {
			Logger.Error("Error al serializar evento de tracking", "error", err)
			return
		}

		req, err := http.NewRequest("POST", url, bytes.NewBuffer(jsonData))
		if err != nil {
			Logger.Error("Error al crear petición de tracking", "error", err)
			return
		}

		req.Header.Set("Content-Type", "application/json")
		// Usar la API Key Server-to-Server
		apiKey := os.Getenv("TRACKING_API_KEY")
		if apiKey != "" {
			req.Header.Set("X-API-Key", apiKey)
		} else {
			Logger.Warn("TRACKING_API_KEY no está configurado")
		}

		client := &http.Client{Timeout: 5 * time.Second}
		resp, err := client.Do(req)
		if err != nil {
			Logger.Error("Error al enviar evento al tracking-service", "error", err, "url", url)
			return
		}
		defer resp.Body.Close()

		if resp.StatusCode != http.StatusAccepted {
			Logger.Warn("Tracking-service respondió con error", "status", resp.Status)
		}
	}()
}
