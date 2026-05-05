package main

import (
	"io"
	"mime/multipart"
	"net/http"
	"path/filepath"
	"strings"
)

// FileValidationConfig contiene la configuración de validación de archivos.
type FileValidationConfig struct {
	MaxSizeBytes      int64
	AllowedExtensions []string
	AllowedMIMETypes  []string
}

// Configuraciones predefinidas para diferentes tipos de archivos.
var (
	// VideoValidationConfig para videos (100MB, formatos comunes)
	VideoValidationConfig = FileValidationConfig{
		MaxSizeBytes:      100 * 1024 * 1024, // 100 MB
		AllowedExtensions: []string{".mp4", ".mov", ".avi", ".webm", ".mkv"},
		AllowedMIMETypes:  []string{"video/mp4", "video/quicktime", "video/x-msvideo", "video/webm", "video/x-matroska"},
	}

	// ImageValidationConfig para imágenes (10MB, formatos comunes)
	ImageValidationConfig = FileValidationConfig{
		MaxSizeBytes:      10 * 1024 * 1024, // 10 MB
		AllowedExtensions: []string{".jpg", ".jpeg", ".png", ".gif", ".webp"},
		AllowedMIMETypes:  []string{"image/jpeg", "image/png", "image/gif", "image/webp"},
	}
)

// FileValidator proporciona validación de archivos subidos.
type FileValidator struct{}

// NewFileValidator crea un nuevo validador de archivos.
func NewFileValidator() *FileValidator {
	return &FileValidator{}
}

// ValidateFile valida un archivo contra una configuración específica.
// Retorna nil si el archivo es válido, o un APIError si hay problemas.
func (fv *FileValidator) ValidateFile(fileHeader *multipart.FileHeader, config FileValidationConfig) *APIError {
	// 1. Validar tamaño
	if fileHeader.Size > config.MaxSizeBytes {
		maxMB := config.MaxSizeBytes / (1024 * 1024)
		return ErrFileTooLarge(int(maxMB))
	}

	// 2. Validar extensión
	ext := strings.ToLower(filepath.Ext(fileHeader.Filename))
	if !fv.isAllowedExtension(ext, config.AllowedExtensions) {
		return ErrInvalidFileType(strings.Join(config.AllowedExtensions, ", "))
	}

	// 3. Validar MIME type real (no confiar solo en la extensión)
	file, err := fileHeader.Open()
	if err != nil {
		return ErrInternal().WithDetails("No se pudo abrir el archivo para validación")
	}
	defer file.Close()

	mimeType, err := fv.detectMIMEType(file)
	if err != nil {
		return ErrInternal().WithDetails("No se pudo detectar el tipo de archivo")
	}

	if !fv.isAllowedMIMEType(mimeType, config.AllowedMIMETypes) {
		Logger.Warn("MIME type no permitido",
			"filename", fileHeader.Filename,
			"detected_mime", mimeType,
			"allowed_mimes", config.AllowedMIMETypes,
		)
		return ErrInvalidFileType(strings.Join(config.AllowedExtensions, ", "))
	}

	return nil
}

// ValidateVideo es un helper para validar videos con la configuración por defecto.
func (fv *FileValidator) ValidateVideo(fileHeader *multipart.FileHeader) *APIError {
	return fv.ValidateFile(fileHeader, VideoValidationConfig)
}

// ValidateImage es un helper para validar imágenes con la configuración por defecto.
func (fv *FileValidator) ValidateImage(fileHeader *multipart.FileHeader) *APIError {
	return fv.ValidateFile(fileHeader, ImageValidationConfig)
}

// detectMIMEType detecta el tipo MIME real del archivo leyendo sus primeros bytes.
func (fv *FileValidator) detectMIMEType(file multipart.File) (string, error) {
	// Leer los primeros 512 bytes para detectar el tipo
	buffer := make([]byte, 512)
	n, err := file.Read(buffer)
	if err != nil && err != io.EOF {
		return "", err
	}

	// Volver al inicio del archivo para que pueda ser leído después
	if seeker, ok := file.(io.Seeker); ok {
		_, err = seeker.Seek(0, io.SeekStart)
		if err != nil {
			return "", err
		}
	}

	// Detectar el tipo MIME
	mimeType := http.DetectContentType(buffer[:n])
	return mimeType, nil
}

// isAllowedExtension verifica si la extensión está en la lista permitida.
func (fv *FileValidator) isAllowedExtension(ext string, allowed []string) bool {
	for _, a := range allowed {
		if strings.EqualFold(ext, a) {
			return true
		}
	}
	return false
}

// isAllowedMIMEType verifica si el MIME type está en la lista permitida.
func (fv *FileValidator) isAllowedMIMEType(mimeType string, allowed []string) bool {
	// El MIME type puede incluir charset, ej: "text/html; charset=utf-8"
	mimeType = strings.Split(mimeType, ";")[0]
	mimeType = strings.TrimSpace(mimeType)

	for _, a := range allowed {
		if strings.EqualFold(mimeType, a) {
			return true
		}
	}
	return false
}

// --- Validadores de entrada (DTOs) ---

// VideoUploadRequest representa los datos para subir un video.
type VideoUploadRequest struct {
	Title       string `form:"title" binding:"required,min=1,max=200"`
	Description string `form:"description" binding:"max=2000"`
}

// CommentRequest representa los datos para crear un comentario.
type CommentRequest struct {
	Text string `json:"text" binding:"required,min=1,max=1000"`
}

// LoginRequest representa los datos para login email/password.
type LoginRequest struct {
	Email    string `json:"email" binding:"required,email"`
	Password string `json:"password" binding:"required,min=8"`
}

// GoogleTokenRequest representa el token de Google para verificar.
type GoogleTokenRequest struct {
	Token string `json:"token" binding:"required"`
}

// Validate valida VideoUploadRequest manualmente (además del binding de Gin).
func (r *VideoUploadRequest) Validate() *APIError {
	if strings.TrimSpace(r.Title) == "" {
		return ErrMissingField("title")
	}
	if len(r.Title) > 200 {
		return ErrInvalidInput("title", "El título no puede exceder 200 caracteres")
	}
	if len(r.Description) > 2000 {
		return ErrInvalidInput("description", "La descripción no puede exceder 2000 caracteres")
	}
	return nil
}

// Validate valida CommentRequest.
func (r *CommentRequest) Validate() *APIError {
	text := strings.TrimSpace(r.Text)
	if text == "" {
		return ErrMissingField("text")
	}
	if len(text) > 1000 {
		return ErrInvalidInput("text", "El comentario no puede exceder 1000 caracteres")
	}
	return nil
}

// Validate valida LoginRequest.
func (r *LoginRequest) Validate() *APIError {
	if strings.TrimSpace(r.Email) == "" {
		return ErrMissingField("email")
	}
	if !strings.Contains(r.Email, "@") {
		return ErrInvalidInput("email", "El email no tiene un formato válido")
	}
	if len(r.Password) < 8 {
		return ErrInvalidInput("password", "La contraseña debe tener al menos 8 caracteres")
	}
	return nil
}
