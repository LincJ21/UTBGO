package main

import (
	"context"
	"fmt"
	"io"
	"os"
	"time"

	"github.com/cloudinary/cloudinary-go/v2"
	"github.com/cloudinary/cloudinary-go/v2/api/uploader"
)

// CloudinaryStorage implementa la interfaz StorageProvider usando Cloudinary.
// Proporciona almacenamiento de medios con CDN global integrado,
// transformaciones automáticas de imagen/video, y un plan gratuito generoso.
//
// Ventajas frente a Azure Blob Storage:
//   - CDN global integrado sin configuración adicional
//   - Transformaciones on-the-fly (resize, crop, formato WebP/AVIF)
//   - Plan gratuito: 25 créditos/mes (~25 GB almacenamiento + 25 GB bandwidth)
//   - Dashboard visual para gestionar archivos
//
// Para activar Cloudinary, configura estas variables de entorno en .env:
//   - STORAGE_PROVIDER=cloudinary
//   - CLOUDINARY_CLOUD_NAME=tu_cloud_name
//   - CLOUDINARY_API_KEY=tu_api_key
//   - CLOUDINARY_API_SECRET=tu_api_secret
type CloudinaryStorage struct {
	client *cloudinary.Cloudinary
}

// NewCloudinaryStorage crea una nueva instancia de CloudinaryStorage.
// Lee las credenciales de las variables de entorno:
//   - CLOUDINARY_CLOUD_NAME: nombre del cloud (ej: "dxyz123abc")
//   - CLOUDINARY_API_KEY: clave API pública
//   - CLOUDINARY_API_SECRET: clave API secreta
//
// Alternativamente, puedes configurar CLOUDINARY_URL con el formato:
//
//	cloudinary://API_KEY:API_SECRET@CLOUD_NAME
func NewCloudinaryStorage() (*CloudinaryStorage, error) {
	cloudName := os.Getenv("CLOUDINARY_CLOUD_NAME")
	apiKey := os.Getenv("CLOUDINARY_API_KEY")
	apiSecret := os.Getenv("CLOUDINARY_API_SECRET")

	var cld *cloudinary.Cloudinary
	var err error

	if cloudName != "" && apiKey != "" && apiSecret != "" {
		// Crear cliente desde parámetros individuales
		cld, err = cloudinary.NewFromParams(cloudName, apiKey, apiSecret)
	} else {
		// Intentar desde CLOUDINARY_URL (formato: cloudinary://KEY:SECRET@CLOUD)
		cld, err = cloudinary.New()
	}

	if err != nil {
		return nil, fmt.Errorf("error al inicializar Cloudinary: %w", err)
	}

	Logger.Info("Cloudinary inicializado", "cloud", cloudName)

	return &CloudinaryStorage{
		client: cld,
	}, nil
}

// UploadImage sube una imagen a Cloudinary.
// Soporta formatos: JPEG, PNG, GIF, WebP, SVG, BMP, TIFF, ICO, PDF.
// Cloudinary detecta el formato automáticamente y aplica optimización.
func (cs *CloudinaryStorage) UploadImage(ctx context.Context, file io.Reader, folder string, publicID string, overwrite bool) (*UploadResult, error) {
	uploadParams := uploader.UploadParams{
		PublicID:     publicID,
		Folder:       folder,
		Overwrite:    boolPtr(overwrite),
		ResourceType: "image",
	}

	result, err := cs.client.Upload.Upload(ctx, file, uploadParams)
	if err != nil {
		return nil, fmt.Errorf("error al subir imagen a Cloudinary: %w", err)
	}

	if result.Error.Message != "" {
		return nil, fmt.Errorf("error de Cloudinary: %s", result.Error.Message)
	}

	url := result.SecureURL
	Logger.Info("Imagen subida a Cloudinary", "url", url, "public_id", result.PublicID)

	return &UploadResult{
		URL:      url,
		PublicID: result.PublicID,
	}, nil
}

// UploadVideo sube un video a Cloudinary.
// Genera un nombre único basado en timestamp para evitar colisiones.
// Cloudinary soporta: MP4, MOV, AVI, WebM, FLV, MKV, 3GP, y más.
// Automáticamente genera thumbnails y permite streaming adaptativo (HLS/DASH).
func (cs *CloudinaryStorage) UploadVideo(ctx context.Context, file io.Reader, folder string) (*UploadResult, error) {
	// Generar nombre único para el video
	videoID := fmt.Sprintf("%d", time.Now().UnixNano())

	uploadParams := uploader.UploadParams{
		PublicID:     videoID,
		Folder:       folder,
		ResourceType: "video",
	}

	result, err := cs.client.Upload.Upload(ctx, file, uploadParams)
	if err != nil {
		return nil, fmt.Errorf("error al subir video a Cloudinary: %w", err)
	}

	if result.Error.Message != "" {
		return nil, fmt.Errorf("error de Cloudinary: %s", result.Error.Message)
	}

	url := result.SecureURL
	Logger.Info("Video subido a Cloudinary", "url", url, "public_id", result.PublicID)

	return &UploadResult{
		URL:      url,
		PublicID: result.PublicID,
	}, nil
}

// GetPublicURL genera la URL pública de un asset en Cloudinary.
// Cloudinary ya devuelve URLs con CDN integrado (res.cloudinary.com).
func (cs *CloudinaryStorage) GetPublicURL(blobPath string) string {
	// En Cloudinary, la URL se genera con el cloud name
	cloudName := cs.client.Config.Cloud.CloudName
	return fmt.Sprintf("https://res.cloudinary.com/%s/image/upload/%s", cloudName, blobPath)
}

// boolPtr es una función auxiliar para convertir un bool a un puntero.
// Necesaria porque el SDK de Cloudinary usa punteros para campos opcionales.
func boolPtr(b bool) *bool {
	return &b
}
