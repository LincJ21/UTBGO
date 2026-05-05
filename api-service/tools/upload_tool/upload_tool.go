package main

import (
	"context"
	"database/sql"
	"fmt"
	"log"
	"os"
	"path/filepath"
	"time"

	"github.com/Azure/azure-sdk-for-go/sdk/storage/azblob"
	_ "github.com/jackc/pgx/v5/stdlib"
	"github.com/joho/godotenv"
)

func main() {
	// --- 1. Cargar configuración desde .env ---
	err := godotenv.Load("../../../../.env")
	if err != nil {
		log.Fatalf("Error al cargar el archivo .env: %v", err)
	}

	// --- 2. Validar argumentos de la línea de comandos ---
	if len(os.Args) < 5 {
		fmt.Println("==============================================")
		fmt.Println("  UTBGO — Herramienta de Subida de Videos")
		fmt.Println("==============================================")
		fmt.Println("Uso: go run . <ruta_al_video> <id_usuario> <titulo> <descripcion>")
		fmt.Println("")
		fmt.Println("Ejemplo:")
		fmt.Println("  go run . \"C:/Videos/mi_video.mp4\" 1 \"Mi Primer Video\" \"Descripción del video\"")
		fmt.Println("")
		os.Exit(1)
	}
	videoPath := os.Args[1]
	userID := os.Args[2]
	title := os.Args[3]
	description := os.Args[4]

	// Verificar que el archivo de video exista
	fileInfo, err := os.Stat(videoPath)
	if os.IsNotExist(err) {
		log.Fatalf("El archivo de video no existe en la ruta: %s", videoPath)
	}
	fileSize := fileInfo.Size()

	log.Printf("Archivo encontrado: %s (%.2f MB)", videoPath, float64(fileSize)/(1024*1024))

	// --- 3. Conectar a Azure Blob Storage ---
	connStr := os.Getenv("AZURE_STORAGE_CONNECTION_STRING")
	if connStr == "" {
		log.Fatal("AZURE_STORAGE_CONNECTION_STRING no está configurada en .env")
	}

	accountName := os.Getenv("AZURE_STORAGE_ACCOUNT")
	if accountName == "" {
		log.Fatal("AZURE_STORAGE_ACCOUNT no está configurada en .env")
	}

	containerName := os.Getenv("AZURE_STORAGE_CONTAINER")
	if containerName == "" {
		containerName = "media"
	}

	client, err := azblob.NewClientFromConnectionString(connStr, nil)
	if err != nil {
		log.Fatalf("Error al crear cliente de Azure Blob Storage: %v", err)
	}
	log.Println("Cliente de Azure Blob Storage inicializado.")

	// --- 4. Conectar a la Base de Datos ---
	db, err := sql.Open("pgx", os.Getenv("DB_CONNECTION_STRING"))
	if err != nil {
		log.Fatalf("Fallo al conectar a la base de datos: %v", err)
	}
	defer db.Close()

	if err = db.Ping(); err != nil {
		log.Fatalf("No se pudo hacer ping a la base de datos: %v", err)
	}
	log.Println("Conexión a la base de datos exitosa.")

	// --- 4.1. Obtener IDs de referencia de la BD ---
	var videoContentTypeID int
	err = db.QueryRow("SELECT id_tipo_contenido FROM tipos_contenido WHERE codigo = $1", "video").Scan(&videoContentTypeID)
	if err != nil {
		log.Fatalf("Error al obtener id_tipo_contenido para 'video': %v", err)
	}

	var publishedContentStateID int
	err = db.QueryRow("SELECT id_estado_contenido FROM estados_contenido WHERE codigo = $1", "publicado").Scan(&publishedContentStateID)
	if err != nil {
		log.Fatalf("Error al obtener id_estado_contenido para 'publicado': %v", err)
	}

	// Verificar que el id_usuario exista
	var userExists bool
	err = db.QueryRow("SELECT EXISTS(SELECT 1 FROM usuarios WHERE id_usuario = $1)", userID).Scan(&userExists)
	if err != nil || !userExists {
		log.Fatalf("El id_usuario %s no existe en la tabla 'usuarios': %v", userID, err)
	}
	log.Printf("Usuario con ID %s verificado.", userID)

	// --- 5. Subir el video a Azure Blob Storage ---
	fileName := filepath.Base(videoPath)
	blobName := fmt.Sprintf("videos/%d_%s", time.Now().UnixNano(), fileName)

	log.Printf("Subiendo a Azure Blob Storage: %s/%s", containerName, blobName)

	// Abrir archivo
	file, err := os.Open(videoPath)
	if err != nil {
		log.Fatalf("Error al abrir el archivo de video: %v", err)
	}
	defer file.Close()

	ctx := context.Background()

	// Subir con streaming
	_, err = client.UploadFile(ctx, containerName, blobName, file, nil)
	if err != nil {
		log.Fatalf("Error al subir a Azure: %v", err)
	}

	// Construir URL pública
	cdnEndpoint := os.Getenv("AZURE_CDN_ENDPOINT")
	var videoURL string
	if cdnEndpoint != "" {
		videoURL = fmt.Sprintf("%s/%s/%s", cdnEndpoint, containerName, blobName)
	} else {
		videoURL = fmt.Sprintf("https://%s.blob.core.windows.net/%s/%s", accountName, containerName, blobName)
	}

	log.Printf("Video subido exitosamente.")
	log.Printf("URL: %s", videoURL)

	// --- 6. Guardar el registro en la base de datos ---
	var videoID int
	err = db.QueryRow(`
		INSERT INTO contenidos (
			titulo, descripcion, id_autor, id_tipo_contenido, id_estado_contenido,
			url_contenido, url_thumbnail, tamanio_bytes,
			fecha_creacion, fecha_publicacion
		) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, NOW(), NOW()) RETURNING id_contenido`,
		title, description, userID, videoContentTypeID, publishedContentStateID,
		videoURL, videoURL, fileSize,
	).Scan(&videoID)

	if err != nil {
		log.Fatalf("Error al guardar en la base de datos: %v", err)
	}

	log.Println("==============================================")
	log.Printf("¡Video registrado exitosamente!")
	log.Printf("ID del contenido: %d", videoID)
	log.Printf("Título: %s", title)
	log.Printf("URL: %s", videoURL)
	log.Println("==============================================")
}

