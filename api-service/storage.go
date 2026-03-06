package main

import (
	"context"
	"io"
)

// UploadResult contiene la información que devuelve cualquier proveedor de almacenamiento
// tras subir un archivo exitosamente.
type UploadResult struct {
	URL      string // URL pública del archivo subido
	PublicID string // Identificador único del archivo en el proveedor
}

// StorageProvider define la interfaz que cualquier proveedor de almacenamiento debe implementar.
// Esto permite cambiar de Azure a S3, Cloudinary, o cualquier otro servicio
// modificando solo la inicialización en main.go, sin tocar los handlers.
type StorageProvider interface {
	// UploadImage sube una imagen al almacenamiento.
	// folder: carpeta destino (ej: "avatars")
	// publicID: identificador único del archivo (ej: "123" para el usuario 123)
	// overwrite: si true, sobreescribe un archivo existente con el mismo publicID
	UploadImage(ctx context.Context, file io.Reader, folder string, publicID string, overwrite bool) (*UploadResult, error)

	// UploadVideo sube un video al almacenamiento.
	// folder: carpeta destino (ej: "videos")
	UploadVideo(ctx context.Context, file io.Reader, folder string) (*UploadResult, error)

	// GetPublicURL genera la URL pública de un archivo dado su path/blobName.
	// Útil para construir URLs de CDN.
	GetPublicURL(blobPath string) string
}

// Storage es la instancia global del proveedor de almacenamiento.
// Se inicializa en main.go y se usa en todos los handlers.
var Storage StorageProvider
