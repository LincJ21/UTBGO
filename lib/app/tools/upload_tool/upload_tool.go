package main

import (
	"context"
	"database/sql"
	"fmt"
	"log"
	"os"
	"path/filepath"

	"github.com/cloudinary/cloudinary-go/v2"
	"github.com/cloudinary/cloudinary-go/v2/api/uploader"
	"github.com/joho/godotenv"
	_ "github.com/lib/pq" // Driver de PostgreSQL
)

func main() {
	// --- 1. Cargar configuración desde .env ---
	// La ruta es relativa al directorio de ejecución (lib/app)
	err := godotenv.Load("../../.env")
	if err != nil {
		log.Fatalf("Error al cargar el archivo .env: %v", err)
	}

	// --- 2. Validar argumentos de la línea de comandos ---
	if len(os.Args) < 5 {
		log.Fatalf("Uso: go run ./upload_tool.go <ruta_al_video> <id_usuario> <titulo_video> <descripcion_video>")
	}
	videoPath := os.Args[1]
	userID := os.Args[2] // El ID del usuario que sube el video
	title := os.Args[3]
	description := os.Args[4]

	// Verificar que el archivo de video exista
	if _, err := os.Stat(videoPath); os.IsNotExist(err) {
		log.Fatalf("El archivo de video no existe en la ruta: %s", videoPath)
	}

	log.Printf("Iniciando subida para el video: %s", videoPath)

	// --- 3. Conectar a Cloudinary ---
	cld, err := cloudinary.NewFromURL(os.Getenv("CLOUDINARY_URL"))
	if err != nil {
		log.Fatalf("Fallo al inicializar Cloudinary: %v", err)
	}

	// --- 4. Conectar a la Base de Datos ---
	db, err := sql.Open("pgx", os.Getenv("DB_CONNECTION_STRING")) // CORRECCIÓN: Usar el nombre de driver 'pgx'
	if err != nil {
		log.Fatalf("Fallo al conectar a la base de datos: %v", err)
	}
	defer db.Close()

	// Probar la conexión a la BD
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
	log.Printf("ID de tipo de contenido 'video': %d", videoContentTypeID)

	var publishedContentStateID int
	err = db.QueryRow("SELECT id_estado_contenido FROM estados_contenido WHERE codigo = $1", "publicado").Scan(&publishedContentStateID)
	if err != nil {
		log.Fatalf("Error al obtener id_estado_contenido para 'publicado': %v", err)
	}
	log.Printf("ID de estado de contenido 'publicado': %d", publishedContentStateID)

	// Verificar que el id_usuario exista
	var userExists bool
	err = db.QueryRow("SELECT EXISTS(SELECT 1 FROM usuarios WHERE id_usuario = $1)", userID).Scan(&userExists)
	if err != nil || !userExists {
		log.Fatalf("El id_usuario %s no existe en la tabla 'usuarios' o hubo un error: %v", userID, err)
	}
	log.Printf("El usuario con ID %s existe.", userID)

	// --- 5. Subir el video a Cloudinary ---
	// Usamos el nombre del archivo como base para el Public ID
	fileName := filepath.Base(videoPath)
	publicID := fmt.Sprintf("videos/%s", fileName)

	log.Printf("Subiendo a Cloudinary con Public ID: %s", publicID)

	ctx := context.Background()
	// CORRECCIÓN 1: El SDK espera un puntero a bool para parámetros opcionales.
	overwrite := true
	uploadResult, err := cld.Upload.Upload(ctx, videoPath, uploader.UploadParams{
		PublicID:     publicID,
		ResourceType: "video", // Especificar que es un video
		Overwrite:    &overwrite,
	})
	if err != nil {
		log.Fatalf("Fallo al subir a Cloudinary: %v", err)
	}

	log.Printf("Video subido exitosamente. URL: %s", uploadResult.SecureURL)
	// CORRECCIÓN 2: La duración ahora está en el campo Video.
	log.Printf("Duración: %f segundos, Tamaño: %d bytes", uploadResult.Video.Duration, uploadResult.Bytes)

	// Generar URL para el thumbnail (primera frame del video como imagen JPG)
	// CORRECCIÓN 3: cld.Image ahora devuelve (asset, error).
	imageAsset, err := cld.Image(uploadResult.PublicID)
	var thumbnailURL string
	if err == nil {
		thumbnailURL, err = imageAsset.
			SetFormat("jpg").
			AddTransformation("w_300,c_fill").
			String()
	}
	if err != nil {
		log.Printf("Advertencia: No se pudo generar la URL del thumbnail: %v", err)
		thumbnailURL = "" // Si falla, no asignamos thumbnail
	} else {
		log.Printf("URL del thumbnail: %s", thumbnailURL)
	}

	// --- 6. Guardar el registro en la base de datos ---
	// Insertar en la tabla 'contenidos'
	stmt, err := db.Prepare(`
		INSERT INTO contenidos (
			titulo, descripcion, id_autor, id_tipo_contenido, id_estado_contenido,
			url_contenido, url_thumbnail, duracion_segundos, tamanio_bytes,
			fecha_creacion, fecha_publicacion
		) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, NOW(), NOW()) RETURNING id_contenido
	`)
	if err != nil {
		log.Fatalf("Error al preparar la sentencia SQL: %v", err)
	}
	defer stmt.Close()

	var newVideoID int
	err = stmt.QueryRow(
		title, description, userID, videoContentTypeID, publishedContentStateID,
		uploadResult.SecureURL, thumbnailURL, int(uploadResult.Video.Duration), uploadResult.Bytes,
	).Scan(&newVideoID)
	if err != nil {
		log.Fatalf("Fallo al insertar el registro del video en la base de datos: %v", err)
	}

	log.Printf("Registro del video guardado en la base de datos con ID: %d", newVideoID)
	log.Println("¡Proceso completado!")
}

/*
--- CÓMO EJECUTAR ESTE SCRIPT ---

1. Asegúrate de tener un video en tu PC. Por ejemplo: /home/usuario/videos/mi_video.mp4

2. Abre tu terminal y navega al directorio `lib/app` de tu proyecto:
   cd /run/media/lincj/datos/flutter_practica (2)/lib/app

3. Ejecuta el script pasándole la ruta del video y el ID de un usuario existente en tu tabla `usuarios`.
   Por ejemplo, si el usuario con id_usuario = 1 existe:

   go run ./upload_tool.go /ruta/a/tu/video.mp4 1

   Ejemplo real:
   go run ./upload_tool.go /home/lincj/Descargas/sample.mp4 1

4. El script subirá el video y guardará el registro. Revisa tu base de datos y Cloudinary para confirmar.
*/
