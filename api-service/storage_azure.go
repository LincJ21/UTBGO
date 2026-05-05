package main

import (
	"context"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/Azure/azure-sdk-for-go/sdk/storage/azblob"
	"github.com/Azure/azure-sdk-for-go/sdk/storage/azblob/blob"
	"github.com/Azure/azure-sdk-for-go/sdk/storage/azblob/container"
)

// AzureStorage implementa la interfaz StorageProvider usando Azure Blob Storage.
// Proporciona almacenamiento escalable, CDN integrada vía Azure CDN/Front Door,
// y es ideal para producción con créditos de Azure for Students.
type AzureStorage struct {
	client      *azblob.Client
	accountName string
	containerName string
	cdnEndpoint string // URL base del CDN de Azure (opcional, si no se usa CDN, usa la URL directa del blob)
}

// NewAzureStorage crea una nueva instancia de AzureStorage.
// Requiere las siguientes variables de entorno:
//   - AZURE_STORAGE_CONNECTION_STRING: cadena de conexión de la cuenta de almacenamiento
//   - AZURE_STORAGE_ACCOUNT: nombre de la cuenta de almacenamiento
//   - AZURE_STORAGE_CONTAINER: nombre del contenedor (ej: "media")
//   - AZURE_CDN_ENDPOINT: (opcional) URL del endpoint de Azure CDN
func NewAzureStorage() (*AzureStorage, error) {
	connStr := os.Getenv("AZURE_STORAGE_CONNECTION_STRING")
	if connStr == "" {
		return nil, fmt.Errorf("AZURE_STORAGE_CONNECTION_STRING no está configurada")
	}

	accountName := os.Getenv("AZURE_STORAGE_ACCOUNT")
	if accountName == "" {
		return nil, fmt.Errorf("AZURE_STORAGE_ACCOUNT no está configurada")
	}

	containerName := os.Getenv("AZURE_STORAGE_CONTAINER")
	if containerName == "" {
		containerName = "media" // Contenedor por defecto
	}

	cdnEndpoint := os.Getenv("AZURE_CDN_ENDPOINT") // Opcional

	client, err := azblob.NewClientFromConnectionString(connStr, nil)
	if err != nil {
		return nil, fmt.Errorf("error al crear el cliente de Azure Blob Storage: %w", err)
	}

	// Asegurar que el contenedor existe. Si ya existe, no hace nada.
	_, err = client.CreateContainer(context.Background(), containerName, &container.CreateOptions{})
	if err != nil {
		Logger.Info("Contenedor verificado", "container", containerName)
	}

	Logger.Info("Azure Blob Storage inicializado", "account", accountName, "container", containerName)

	return &AzureStorage{
		client:        client,
		accountName:   accountName,
		containerName: containerName,
		cdnEndpoint:   cdnEndpoint,
	}, nil
}

// UploadImage sube una imagen a Azure Blob Storage.
func (as *AzureStorage) UploadImage(ctx context.Context, file io.Reader, folder string, publicID string, overwrite bool) (*UploadResult, error) {
	blobName := fmt.Sprintf("%s/%s", folder, publicID)

	// Detectar MIME type por extensión del publicID
	contentType := detectImageContentType(publicID)

	uploadOptions := &azblob.UploadStreamOptions{
		BlockSize:   4 * 1024 * 1024,
		Concurrency: 3,
		HTTPHeaders: &blob.HTTPHeaders{
			BlobContentType: toPtr(contentType),
		},
	}

	_, err := as.client.UploadStream(ctx, as.containerName, blobName, file, uploadOptions)
	if err != nil {
		return nil, fmt.Errorf("error al subir imagen a Azure: %w", err)
	}

	url := as.GetPublicURL(blobName)
	Logger.Info("Imagen subida a Azure", "url", url)

	return &UploadResult{
		URL:      url,
		PublicID: blobName,
	}, nil
}

// UploadVideo sube un video a Azure Blob Storage.
// Genera un nombre único basado en timestamp para evitar colisiones.
func (as *AzureStorage) UploadVideo(ctx context.Context, file io.Reader, folder string) (*UploadResult, error) {
	// Generar nombre único para el video
	blobName := fmt.Sprintf("%s/%d.mp4", folder, time.Now().UnixNano())

	// Configurar opciones optimizadas para videos (archivos grandes)
	uploadOptions := &azblob.UploadStreamOptions{
		BlockSize:   8 * 1024 * 1024, // 8 MB por bloque (más grande para videos)
		Concurrency: 5,               // 5 bloques en paralelo para subida rápida
		HTTPHeaders: &blob.HTTPHeaders{
			BlobContentType:  toPtr("video/mp4"),
			BlobCacheControl: toPtr("public, max-age=31536000"), // Cache de 1 año (el contenido no cambia)
		},
	}

	_, err := as.client.UploadStream(ctx, as.containerName, blobName, file, uploadOptions)
	if err != nil {
		return nil, fmt.Errorf("error al subir video a Azure: %w", err)
	}

	url := as.GetPublicURL(blobName)
	Logger.Info("Video subido a Azure", "url", url)

	return &UploadResult{
		URL:      url,
		PublicID: blobName,
	}, nil
}

// detectImageContentType detecta el MIME type de una imagen por su extensión.
func detectImageContentType(filename string) string {
	ext := strings.ToLower(filepath.Ext(filename))
	switch ext {
	case ".png":
		return "image/png"
	case ".gif":
		return "image/gif"
	case ".webp":
		return "image/webp"
	case ".svg":
		return "image/svg+xml"
	default:
		return "image/jpeg"
	}
}

// GetPublicURL genera la URL pública de un blob.
// Si hay un CDN configurado, usa la URL del CDN (más rápido para los usuarios).
// Si no, usa la URL directa de Azure Blob Storage.
func (as *AzureStorage) GetPublicURL(blobPath string) string {
	if as.cdnEndpoint != "" {
		return fmt.Sprintf("%s/%s/%s", as.cdnEndpoint, as.containerName, blobPath)
	}
	return fmt.Sprintf("https://%s.blob.core.windows.net/%s/%s", as.accountName, as.containerName, blobPath)
}

// toPtr es una función auxiliar para convertir un string a un puntero.
// Necesaria porque el SDK de Azure usa punteros para campos opcionales.
func toPtr(s string) *string {
	return &s
}
