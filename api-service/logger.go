package main

import (
	"log/slog"
	"os"
)

// Logger es el logger estructurado global de la aplicación.
// Usa slog (Go 1.21+) para output JSON en producción y texto en desarrollo.
var Logger *slog.Logger

// InitLogger inicializa el logger según el entorno.
// En producción (GIN_MODE=release) usa formato JSON, en desarrollo usa texto legible.
func InitLogger() {
	var handler slog.Handler

	if os.Getenv("GIN_MODE") == "release" {
		// Producción: JSON para fácil parseo por herramientas de log
		handler = slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{
			Level:     slog.LevelInfo,
			AddSource: true, // Incluir archivo:línea en los logs
		})
	} else {
		// Desarrollo: Texto legible con colores
		handler = slog.NewTextHandler(os.Stdout, &slog.HandlerOptions{
			Level:     slog.LevelDebug, // Más verbose en desarrollo
			AddSource: false,
		})
	}

	Logger = slog.New(handler)
	slog.SetDefault(Logger) // Permite usar slog.Info() directamente

	Logger.Info("Logger inicializado",
		slog.String("mode", os.Getenv("GIN_MODE")),
		slog.String("format", func() string {
			if os.Getenv("GIN_MODE") == "release" {
				return "json"
			}
			return "text"
		}()),
	)
}

// LogRequest crea un logger con contexto de request para trazabilidad.
func LogRequest(requestID, method, path, userIP string) *slog.Logger {
	return Logger.With(
		slog.String("request_id", requestID),
		slog.String("method", method),
		slog.String("path", path),
		slog.String("client_ip", userIP),
	)
}

// LogError registra un error con contexto adicional.
func LogError(err error, msg string, attrs ...any) {
	allAttrs := append([]any{slog.Any("error", err)}, attrs...)
	Logger.Error(msg, allAttrs...)
}

// LogDB registra operaciones de base de datos.
func LogDB(operation, table string, duration int64, err error) {
	attrs := []any{
		slog.String("operation", operation),
		slog.String("table", table),
		slog.Int64("duration_ms", duration),
	}
	if err != nil {
		attrs = append(attrs, slog.Any("error", err))
		Logger.Error("Database operation failed", attrs...)
	} else {
		Logger.Debug("Database operation completed", attrs...)
	}
}
