package main

import (
	"fmt"
	"net/http"

	"github.com/gin-gonic/gin"
)

// ErrorCode representa códigos de error únicos de la API.
// Esto permite a los clientes manejar errores específicos programáticamente.
type ErrorCode string

const (
	// Errores de autenticación (1xxx)
	ErrCodeUnauthorized      ErrorCode = "AUTH_001"
	ErrCodeInvalidToken      ErrorCode = "AUTH_002"
	ErrCodeTokenExpired      ErrorCode = "AUTH_003"
	ErrCodeMissingToken      ErrorCode = "AUTH_004"
	ErrCodeInvalidCredentials ErrorCode = "AUTH_005"
	ErrCodeForbidden          ErrorCode = "AUTH_006"

	// Errores de validación (2xxx)
	ErrCodeValidation        ErrorCode = "VAL_001"
	ErrCodeInvalidInput      ErrorCode = "VAL_002"
	ErrCodeMissingField      ErrorCode = "VAL_003"
	ErrCodeInvalidFormat     ErrorCode = "VAL_004"
	ErrCodeFileTooLarge      ErrorCode = "VAL_005"
	ErrCodeInvalidFileType   ErrorCode = "VAL_006"

	// Errores de recursos (3xxx)
	ErrCodeNotFound          ErrorCode = "RES_001"
	ErrCodeAlreadyExists     ErrorCode = "RES_002"
	ErrCodeConflict          ErrorCode = "RES_003"

	// Errores de servidor (4xxx)
	ErrCodeInternal          ErrorCode = "SRV_001"
	ErrCodeDatabase          ErrorCode = "SRV_002"
	ErrCodeExternalService   ErrorCode = "SRV_003"
	ErrCodeStorageError      ErrorCode = "SRV_004"

	// Errores de rate limiting (5xxx)
	ErrCodeRateLimited       ErrorCode = "RATE_001"
)

// APIError representa un error estructurado de la API.
type APIError struct {
	Code       ErrorCode `json:"code"`
	Message    string    `json:"message"`
	Details    string    `json:"details,omitempty"`    // Detalles adicionales (solo en desarrollo)
	Field      string    `json:"field,omitempty"`      // Campo específico que causó el error
	HTTPStatus int       `json:"-"`                    // No se serializa, solo para uso interno
}

func (e *APIError) Error() string {
	return fmt.Sprintf("[%s] %s", e.Code, e.Message)
}

// NewAPIError crea un nuevo error de API.
func NewAPIError(code ErrorCode, message string, httpStatus int) *APIError {
	return &APIError{
		Code:       code,
		Message:    message,
		HTTPStatus: httpStatus,
	}
}

// WithDetails añade detalles al error (útil para debugging).
func (e *APIError) WithDetails(details string) *APIError {
	e.Details = details
	return e
}

// WithField indica qué campo causó el error.
func (e *APIError) WithField(field string) *APIError {
	e.Field = field
	return e
}

// --- Errores predefinidos comunes ---

// Errores de autenticación
func ErrUnauthorized() *APIError {
	return NewAPIError(ErrCodeUnauthorized, "No autorizado", http.StatusUnauthorized)
}

func ErrForbidden(message string) *APIError {
	return NewAPIError(ErrCodeForbidden, message, http.StatusForbidden)
}

func ErrInvalidToken() *APIError {
	return NewAPIError(ErrCodeInvalidToken, "Token inválido", http.StatusUnauthorized)
}

func ErrTokenExpired() *APIError {
	return NewAPIError(ErrCodeTokenExpired, "Token expirado", http.StatusUnauthorized)
}

func ErrMissingToken() *APIError {
	return NewAPIError(ErrCodeMissingToken, "Token no proporcionado", http.StatusUnauthorized)
}

func ErrInvalidCredentials() *APIError {
	return NewAPIError(ErrCodeInvalidCredentials, "Credenciales inválidas", http.StatusUnauthorized)
}

// Errores de validación
func ErrValidation(message string) *APIError {
	return NewAPIError(ErrCodeValidation, message, http.StatusBadRequest)
}

func ErrInvalidInput(field, message string) *APIError {
	return NewAPIError(ErrCodeInvalidInput, message, http.StatusBadRequest).WithField(field)
}

func ErrMissingField(field string) *APIError {
	return NewAPIError(ErrCodeMissingField, fmt.Sprintf("El campo '%s' es requerido", field), http.StatusBadRequest).WithField(field)
}

func ErrFileTooLarge(maxSizeMB int) *APIError {
	return NewAPIError(ErrCodeFileTooLarge, fmt.Sprintf("El archivo excede el tamaño máximo permitido (%dMB)", maxSizeMB), http.StatusRequestEntityTooLarge)
}

func ErrInvalidFileType(allowedTypes string) *APIError {
	return NewAPIError(ErrCodeInvalidFileType, fmt.Sprintf("Tipo de archivo no permitido. Formatos válidos: %s", allowedTypes), http.StatusBadRequest)
}

// Errores de recursos
func ErrNotFound(resource string) *APIError {
	return NewAPIError(ErrCodeNotFound, fmt.Sprintf("%s no encontrado", resource), http.StatusNotFound)
}

func ErrAlreadyExists(resource string) *APIError {
	return NewAPIError(ErrCodeAlreadyExists, fmt.Sprintf("%s ya existe", resource), http.StatusConflict)
}

// Errores de servidor
func ErrInternal() *APIError {
	return NewAPIError(ErrCodeInternal, "Error interno del servidor", http.StatusInternalServerError)
}

func ErrDatabase(details string) *APIError {
	return NewAPIError(ErrCodeDatabase, "Error de base de datos", http.StatusInternalServerError).WithDetails(details)
}

func ErrStorage(details string) *APIError {
	return NewAPIError(ErrCodeStorageError, "Error de almacenamiento", http.StatusInternalServerError).WithDetails(details)
}

// Rate limiting
func ErrRateLimited() *APIError {
	return NewAPIError(ErrCodeRateLimited, "Demasiadas solicitudes. Por favor, espera un momento.", http.StatusTooManyRequests)
}

// --- Helpers para respuestas ---

// RespondError envía una respuesta de error JSON al cliente.
func RespondError(c *gin.Context, err *APIError) {
	// Log del error
	Logger.Error("API Error",
		"code", err.Code,
		"message", err.Message,
		"details", err.Details,
		"path", c.Request.URL.Path,
		"method", c.Request.Method,
	)

	// En desarrollo, incluir detalles; en producción, omitirlos
	if gin.Mode() == gin.ReleaseMode {
		err.Details = "" // Ocultar detalles internos en producción
	}

	c.JSON(err.HTTPStatus, gin.H{"error": err})
}

// RespondSuccess envía una respuesta exitosa JSON.
func RespondSuccess(c *gin.Context, data interface{}) {
	c.JSON(http.StatusOK, data)
}

// RespondCreated envía una respuesta 201 Created.
func RespondCreated(c *gin.Context, data interface{}) {
	c.JSON(http.StatusCreated, data)
}

// RespondNoContent envía una respuesta 204 No Content.
func RespondNoContent(c *gin.Context) {
	c.Status(http.StatusNoContent)
}
