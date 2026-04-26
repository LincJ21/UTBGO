package main

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"
	"os"
	"log/slog"

	"github.com/gin-gonic/gin"
)

func init() {
	// Initialize the global logger to discard output during tests
	Logger = slog.New(slog.NewTextHandler(os.Stderr, nil))
}

// TestLoginMissingCredentials verifica que enviar un payload vacío al endpoint de login
// es rechazado correctamente con 400 Bad Request, previniendo errores internos.
func TestLoginMissingCredentials(t *testing.T) {
	// Configurar Gin en modo test para evitar logs innecesarios
	gin.SetMode(gin.TestMode)

	// Crear un router simulado
	router := gin.New()
	router.POST("/api/v1/auth/login", handleLoginV2)

	// Crear una petición HTTP simulada con JSON vacío
	reqBody := []byte(`{}`)
	req, _ := http.NewRequest("POST", "/api/v1/auth/login", bytes.NewBuffer(reqBody))
	req.Header.Set("Content-Type", "application/json")

	// Crear un ResponseRecorder para capturar la respuesta
	w := httptest.NewRecorder()

	// Ejecutar la petición
	router.ServeHTTP(w, req)

	// Verificaciones OWASP (Input Validation)
	if w.Code != http.StatusBadRequest {
		t.Errorf("Expected status %d, but got %d", http.StatusBadRequest, w.Code)
	}

	// Verificar que la respuesta contiene el formato esperado de error
	var response map[string]interface{}
	err := json.Unmarshal(w.Body.Bytes(), &response)
	if err != nil {
		t.Fatalf("Failed to parse response JSON: %v", err)
	}

	if _, exists := response["error"]; !exists {
		t.Errorf("Expected 'error' field in response, got %v", response)
	}
}

// TestRateLimiterCreation verifica que el limitador de solicitudes no devuelva un puntero nulo
// y se inicialice correctamente.
func TestRateLimiterCreation(t *testing.T) {
	// Intentamos crear un RedisRateLimiter con un cliente de prueba nil y ventana de 1 minuto
	limiter := NewRedisRateLimiter(nil, 100, time.Minute)
	
	if limiter == nil {
		t.Error("Rate limiter creation failed, expected a non-nil object")
	}
}
