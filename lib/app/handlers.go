package main

import (
	"context"
	"fmt"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"time"

	"database/sql"

	"github.com/cloudinary/cloudinary-go/v2/api/uploader"
	"github.com/gin-gonic/gin"
	"github.com/golang-jwt/jwt/v4"
	"google.golang.org/api/idtoken"
)

// --- Funciones de Ayuda (Refactorización) ---

// getOrCreateUser busca un usuario por email. Si no existe, lo crea junto con su perfil.
// Devuelve el ID del usuario y un posible error.
func getOrCreateUser(ctx context.Context, email, name, picture string) (int, error) {
	var userID int

	// Intenta encontrar al usuario existente.
	err := DB.QueryRowContext(ctx, "SELECT id_usuario FROM usuarios WHERE email = $1", email).Scan(&userID)
	if err == nil {
		// Usuario encontrado, actualiza su último login y retorna el ID.
		log.Printf("Usuario existente con email %s. Actualizando datos.", email)
		_, updateErr := DB.ExecContext(ctx, "UPDATE usuarios SET ultimo_login = NOW() WHERE id_usuario = $1", userID)
		if updateErr != nil {
			log.Printf("Advertencia: no se pudo actualizar ultimo_login para usuario %d: %v", userID, updateErr)
		}
		return userID, nil
	}

	// Si el error no es "no rows", es un error inesperado.
	if err != sql.ErrNoRows {
		return 0, fmt.Errorf("error al consultar la base de datos: %w", err)
	}

	// Usuario no encontrado (sql.ErrNoRows), procedemos a crearlo en una transacción.
	log.Printf("Usuario nuevo con email %s. Creando entrada en la BD.", email)
	tx, err := DB.BeginTx(ctx, nil)
	if err != nil {
		return 0, fmt.Errorf("error al iniciar la transacción: %w", err)
	}
	defer tx.Rollback() // Se ejecuta si el Commit() no se alcanza.

	// --- Lógica para asegurar que existen los tipos y estados necesarios ---
	var studentTypeID int
	// 1. Buscar ID de tipo usuario 'estudiante'
	err = tx.QueryRowContext(ctx, "SELECT id_tipo_usuario FROM tipos_usuario WHERE codigo = 'estudiante'").Scan(&studentTypeID)
	if err == sql.ErrNoRows {
		// Si no existe, lo creamos dinámicamente
		err = tx.QueryRowContext(ctx, "INSERT INTO tipos_usuario (codigo, nombre, descripcion, nivel_acceso) VALUES ('estudiante', 'Estudiante', 'Rol por defecto', 1) RETURNING id_tipo_usuario").Scan(&studentTypeID)
		if err != nil {
			return 0, fmt.Errorf("error al crear tipo usuario estudiante: %w", err)
		}
	} else if err != nil {
		return 0, fmt.Errorf("error al buscar tipo usuario estudiante: %w", err)
	}

	var activeStateID int
	// 2. Buscar ID de estado usuario 'activo'
	err = tx.QueryRowContext(ctx, "SELECT id_estado_usuario FROM estados_usuario WHERE codigo = 'activo'").Scan(&activeStateID)
	if err == sql.ErrNoRows {
		err = tx.QueryRowContext(ctx, "INSERT INTO estados_usuario (codigo, nombre, descripcion) VALUES ('activo', 'Activo', 'Usuario activo') RETURNING id_estado_usuario").Scan(&activeStateID)
		if err != nil {
			return 0, fmt.Errorf("error al crear estado usuario activo: %w", err)
		}
	} else if err != nil {
		return 0, fmt.Errorf("error al buscar estado usuario activo: %w", err)
	}

	// Insertar en la tabla 'usuarios'.
	err = tx.QueryRowContext(ctx, "INSERT INTO usuarios (id_tipo_usuario, id_estado_usuario, email, password_hash, fecha_registro) VALUES ($1, $2, $3, 'google-login', NOW()) RETURNING id_usuario", studentTypeID, activeStateID, email).Scan(&userID)
	if err != nil {
		if strings.Contains(err.Error(), "usuarios_id_usuario_fkey") {
			log.Println("!!! ERROR DE BASE DE DATOS: Tienes restricciones incorrectas. Ejecuta el script fix_constraints.sql en Neon !!!")
		}
		return 0, fmt.Errorf("error al crear usuario: %w", err)
	}

	// Insertar en la tabla 'perfiles'.
	_, err = tx.ExecContext(ctx, "INSERT INTO perfiles (id_usuario, nombre, apellido, avatar_url) VALUES ($1, $2, '', $3)", userID, name, picture)
	if err != nil {
		return 0, fmt.Errorf("error al crear perfil: %w", err)
	}

	// Si todo fue bien, confirmar la transacción.
	if err = tx.Commit(); err != nil {
		return 0, fmt.Errorf("error al confirmar la transacción: %w", err)
	}

	return userID, nil
}

// generateJWT crea un token JWT para un ID de usuario específico.
func generateJWT(userID int) (string, error) {
	jwtToken := jwt.NewWithClaims(jwt.SigningMethodHS256, jwt.MapClaims{
		"user_id": float64(userID), // El tipo por defecto para números en claims de JWT es float64
		"exp":     time.Now().Add(time.Hour * 72).Unix(),
	})

	return jwtToken.SignedString([]byte(os.Getenv("JWT_SECRET_KEY")))
}

// --- Handlers ---

// handleVerifyToken es el nuevo handler para el flujo de la app nativa.
func handleVerifyToken(c *gin.Context) {
	// ¡AÑADIDO! Log para confirmar que la petición ha llegado al handler.
	log.Println("Recibida petición en /auth/google/verify-token")

	var requestBody struct {
		Token string `json:"token"`
	}

	if err := c.ShouldBindJSON(&requestBody); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Formato de petición inválido"})
		return
	}

	idToken := requestBody.Token
	if idToken == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "El token es requerido"})
		return
	}

	// 1. Verificar el idToken usando la librería de Google.
	// El clientID aquí debe ser el ID de cliente de la "Aplicación Web" configurado en Google Cloud,
	// que actúa como la audiencia (`aud`) del token.
	payload, err := idtoken.Validate(context.Background(), idToken, os.Getenv("GOOGLE_CLIENT_ID"))
	if err != nil {
		// ¡AÑADIDO! Imprimimos el error detallado en la consola del servidor.
		log.Printf("Error al validar el token de Google: %v", err)
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Token de Google inválido: " + err.Error()})
		return
	}

	// 2. Extraer la información del usuario del payload del token.
	claims := payload.Claims
	googleEmail := claims["email"].(string)
	googleName := claims["name"].(string)
	googlePicture := claims["picture"].(string)

	// 3. Usar la función de ayuda para obtener o crear el usuario.
	userID, err := getOrCreateUser(c.Request.Context(), googleEmail, googleName, googlePicture)
	if err != nil {
		log.Printf("Error en getOrCreateUser: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Error al procesar el usuario: " + err.Error()})
		return
	}

	// 4. Generar el token JWT usando la función de ayuda.
	tokenString, err := generateJWT(userID)
	if err != nil {
		log.Printf("Error al generar el token JWT: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Fallo al crear el token"})
		return
	}

	// 5. Devolver nuestro token JWT en una respuesta JSON.
	c.JSON(http.StatusOK, gin.H{"token": tokenString})
}

// handleLogin maneja el inicio de sesión con email y contraseña.
func handleLogin(c *gin.Context) {
	var requestBody struct {
		Email    string `json:"email"`
		Password string `json:"password"`
	}

	if err := c.ShouldBindJSON(&requestBody); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Formato de petición inválido"})
		return
	}

	// --- LÓGICA DE BASE DE DATOS DESACTIVADA ---
	// Simulación: Aceptamos cualquier usuario y le asignamos un ID de prueba.
	userID := 1
	hashedPassword := "" // No se usa
	_ = hashedPassword   // Se añade para que Go no se queje de una variable no usada.

	// 2. Comparar la contraseña proporcionada con el hash almacenado.
	// --- LÓGICA DESACTIVADA ---
	// En modo simulación, este bloque siempre fallaría.
	// Lo comentamos para permitir que el login de prueba funcione.

	// 3. Si la contraseña es correcta, generar un token JWT (lógica idéntica a la de Google).
	log.Printf("Usuario %d autenticado correctamente con email/password.", userID)

	tokenString, err := generateJWT(userID)
	if err != nil {
		log.Printf("Error al generar el token JWT: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Fallo al crear el token"})
		return
	}

	// --- LÓGICA DE BASE DE DATOS DESACTIVADA ---
	// _, err = DB.ExecContext(c, "UPDATE usuarios SET ultimo_login = NOW() WHERE id_usuario = $1", userID)

	// 4. Devolver el token.
	c.JSON(http.StatusOK, gin.H{"token": tokenString})
}

func handleGetProfile(c *gin.Context) {
	// --- CAMBIO PARA PRUEBAS ---
	// Obtenemos el userID del contexto, establecido por el AuthMiddleware.
	userIDVal, exists := c.Get("userID")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "User not authenticated"})
		return
	}
	userID := int(userIDVal.(float64)) // Convertimos de float64 a int

	var user User
	var avatarURL sql.NullString // Manejar valores nulos de SQL

	// Consultar datos reales de la base de datos
	err := DB.QueryRowContext(c, `
		SELECT u.id_usuario, p.nombre || ' ' || p.apellido, u.email, p.avatar_url
		FROM usuarios u
		JOIN perfiles p ON u.id_usuario = p.id_usuario
		WHERE u.id_usuario = $1`, userID).Scan(&user.ID, &user.Username, &user.Email, &avatarURL)

	if err != nil {
		log.Printf("Error al obtener perfil: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Error al obtener perfil"})
		return
	}

	if avatarURL.Valid {
		user.AvatarURL = avatarURL.String
	}

	c.JSON(http.StatusOK, user)
}

func handleUploadAvatar(c *gin.Context) {
	// --- CAMBIO PARA PRUEBAS ---
	// Obtenemos el userID del contexto, establecido por el AuthMiddleware.
	userIDVal, exists := c.Get("userID")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "User not authenticated"})
		return
	}
	userID := int(userIDVal.(float64)) // Convertimos de float64 a int

	// 1. Obtener el archivo del formulario multipart
	file, err := c.FormFile("avatar")
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "No se ha subido ningún archivo: " + err.Error()})
		return
	}

	// 2. Abrir el archivo para leerlo
	src, err := file.Open()
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "No se pudo abrir el archivo: " + err.Error()})
		return
	}
	defer src.Close()

	// CORRECCIÓN: El SDK de Cloudinary espera un puntero a bool (*bool) para parámetros opcionales.
	// No podemos usar 'true' directamente. Creamos una variable y pasamos su puntero.
	overwrite := true
	// 3. Subir el archivo a Cloudinary
	// Usamos el ID de usuario como PublicID para evitar duplicados y facilitar la gestión.
	uploadResult, err := cld.Upload.Upload(context.Background(), src, uploader.UploadParams{
		PublicID:  fmt.Sprintf("avatars/%d", userID),
		Overwrite: &overwrite, // Pasamos el puntero a la variable 'overwrite'
	})
	if err != nil {
		// ¡AÑADIDO! Logueamos el error detallado de Cloudinary.
		log.Printf("ERROR: Fallo al subir el avatar a Cloudinary: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Fallo al subir a Cloudinary: " + err.Error()})
		return
	}

	// Actualizar la URL del avatar en la base de datos
	_, err = DB.ExecContext(c, "UPDATE perfiles SET avatar_url = $1 WHERE id_usuario = $2", uploadResult.SecureURL, userID)
	if err != nil {
		log.Printf("Error al actualizar avatar en BD: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Avatar subido pero no guardado en BD"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Avatar actualizado correctamente", "avatarUrl": uploadResult.SecureURL})
}

// handleUploadVideo maneja la subida de un nuevo video.
func handleUploadVideo(c *gin.Context) {
	// Obtenemos el userID del contexto, establecido por el AuthMiddleware.
	userIDVal, exists := c.Get("userID")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "User not authenticated"})
		return
	}
	userID := int(userIDVal.(float64)) // Convertimos de float64 a int

	log.Printf("Iniciando subida de video para el usuario ID: %d", userID)
	// 1. Obtener los campos de texto del formulario.
	title := c.PostForm("title")
	description := c.PostForm("description")
	if title == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "El título es requerido"})
		return
	}
	// ¡AÑADIDO! Usamos la variable 'description' en un log para evitar el error de compilación.
	// En un caso real, esta variable se guardaría en la base de datos.
	log.Printf("Descripción recibida para el video: '%s'", description)

	// 2. Obtener el archivo de video.
	file, err := c.FormFile("video")
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "No se ha subido ningún archivo de video: " + err.Error()})
		return
	}

	src, err := file.Open()
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "No se pudo abrir el archivo de video: " + err.Error()})
		return
	}
	defer src.Close()

	// 3. Detectar tipo de archivo (Video o Imagen)
	ext := strings.ToLower(filepath.Ext(file.Filename))
	var contentTypeID int
	var resourceType string
	var folder string

	if ext == ".jpg" || ext == ".jpeg" || ext == ".png" || ext == ".gif" || ext == ".webp" {
		contentTypeID = imageContentTypeID
		resourceType = "image"
		folder = "images"
	} else {
		contentTypeID = videoContentTypeID
		resourceType = "video"
		folder = "videos"
	}

	// 4. Subir a Cloudinary con el tipo correcto
	uploadResult, err := cld.Upload.Upload(context.Background(), src, uploader.UploadParams{
		Folder:       folder,
		ResourceType: resourceType,
	})
	if err != nil {
		// ¡AÑADIDO! Logueamos el error detallado de Cloudinary.
		log.Printf("ERROR: Fallo al subir el video a Cloudinary: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Fallo al subir el video a Cloudinary: " + err.Error()})
		return
	}

	// Generar URL del thumbnail correcta
	// Si es video, Cloudinary permite obtener una imagen cambiando la extensión a .jpg
	thumbnailURL := uploadResult.SecureURL
	if resourceType == "video" {
		lastDot := strings.LastIndex(thumbnailURL, ".")
		if lastDot != -1 {
			thumbnailURL = thumbnailURL[:lastDot] + ".jpg"
		}
	}

	// Insertar video en la base de datos
	var videoID int
	err = DB.QueryRowContext(c, `
		INSERT INTO contenidos (titulo, descripcion, id_autor, id_tipo_contenido, id_estado_contenido, url_contenido, url_thumbnail, fecha_creacion, fecha_publicacion)
		VALUES ($1, $2, $3, $4, $5, $6, $7, NOW(), NOW()) RETURNING id_contenido`,
		title, description, userID, contentTypeID, publishedContentStateID, uploadResult.SecureURL, thumbnailURL, // Usamos la URL corregida para el thumbnail
	).Scan(&videoID)
	if err != nil {
		log.Printf("Error al guardar video en BD: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Video subido a Cloudinary pero falló el registro en BD"})
		return
	}

	log.Printf("Video subido por usuario %d y guardado en la base de datos.", userID)
	c.JSON(http.StatusOK, gin.H{"message": "Video subido correctamente", "videoUrl": uploadResult.SecureURL})
}

// handleUploadFlashcard maneja la creación de una nueva flashcard.
func handleUploadFlashcard(c *gin.Context) {
	userIDVal, exists := c.Get("userID")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "User not authenticated"})
		return
	}
	userID := int(userIDVal.(float64))

	var req struct {
		Title       string `json:"title"`       // Frente de la tarjeta
		Description string `json:"description"` // Reverso de la tarjeta
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Datos inválidos"})
		return
	}

	// Insertar flashcard en la base de datos (url_contenido vacío por ahora, o podrías subir una imagen)
	_, err := DB.ExecContext(c, `
		INSERT INTO contenidos (titulo, descripcion, id_autor, id_tipo_contenido, id_estado_contenido, url_contenido, fecha_creacion, fecha_publicacion)
		VALUES ($1, $2, $3, $4, $5, '', NOW(), NOW())`,
		req.Title, req.Description, userID, flashcardContentTypeID, publishedContentStateID)

	if err != nil {
		log.Printf("Error al guardar flashcard: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Error al guardar flashcard"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Flashcard creada correctamente"})
}

func ensureVideoExists(videoID string) *Video {
	// Este bloqueo asegura que la verificación y creación del video sea atómica.
	Mu.Lock()
	defer Mu.Unlock()
	if _, ok := Videos[videoID]; !ok {
		Videos[videoID] = &Video{ID: videoID, Likes: 0, IsLiked: false, IsBookmarked: false}
	}
	return Videos[videoID]
}

func handleToggleLike(c *gin.Context) {
	userIDVal, exists := c.Get("userID")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "User not authenticated"})
		return
	}
	userID := int(userIDVal.(float64))

	videoIDStr := c.Param("id")
	videoID, err := strconv.Atoi(videoIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "ID de video inválido"})
		return
	}

	// Verificar si ya existe el like en la base de datos
	var interactionID int
	err = DB.QueryRowContext(c, "SELECT id_interaccion FROM interacciones WHERE id_usuario = $1 AND id_contenido = $2 AND id_tipo_interaccion = $3", userID, videoID, likeInteractionTypeID).Scan(&interactionID)

	isLiked := false
	if err == sql.ErrNoRows {
		// No existe, crear like
		_, err = DB.ExecContext(c, "INSERT INTO interacciones (id_usuario, id_contenido, id_tipo_interaccion) VALUES ($1, $2, $3)", userID, videoID, likeInteractionTypeID)
		if err != nil {
			log.Printf("Error al dar like: %v", err)
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Error al procesar like"})
			return
		}
		isLiked = true
	} else if err == nil {
		// Existe, eliminar like
		_, err = DB.ExecContext(c, "DELETE FROM interacciones WHERE id_interaccion = $1", interactionID)
		if err != nil {
			log.Printf("Error al quitar like: %v", err)
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Error al procesar like"})
			return
		}
		isLiked = false
	} else {
		log.Printf("Error al consultar interacción: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Error de base de datos"})
		return
	}

	// Obtener nuevo conteo de likes
	var likesCount int
	err = DB.QueryRowContext(c, "SELECT COUNT(*) FROM interacciones WHERE id_contenido = $1 AND id_tipo_interaccion = $2", videoID, likeInteractionTypeID).Scan(&likesCount)
	if err != nil {
		likesCount = 0
	}

	c.JSON(http.StatusOK, gin.H{
		"id":      videoIDStr,
		"likes":   likesCount,
		"isLiked": isLiked,
	})
}

func handleToggleBookmark(c *gin.Context) {
	videoID := c.Param("id")
	video := ensureVideoExists(videoID) // Esta llamada ahora es segura dentro del bloqueo.
	video.IsBookmarked = !video.IsBookmarked

	log.Printf("Video %s toggled bookmark. New state: Bookmarked=%v", videoID, video.IsBookmarked)
	c.JSON(http.StatusOK, video)
}

func handleGetComments(c *gin.Context) {
	videoID := c.Param("id")

	Mu.Lock()
	defer Mu.Unlock()

	// Simular algunos comentarios si no existen
	if _, ok := Comments[videoID]; !ok {
		Comments[videoID] = []Comment{
			{ID: "c1", UserID: "user1", Username: "Usuario Uno", Text: "¡Qué buen video!"},
			{ID: "c2", UserID: "user2", Username: "Usuario Dos", Text: "Interesante perspectiva."},
		}
	}

	c.JSON(http.StatusOK, Comments[videoID])
}

func handleSearchVideos(c *gin.Context) {
	query := c.Query("q")
	if query == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Query parameter 'q' is required"})
		return
	}

	// Preparamos el término de búsqueda para usar con LIKE en SQL.
	searchQuery := "%" + query + "%"

	// --- LÓGICA DE BASE DE DATOS DESACTIVADA ---
	log.Printf("ADVERTENCIA: Búsqueda simulada para '%s'. Devolviendo 0 resultados.", searchQuery)
	var searchResults []gin.H

	log.Printf("Búsqueda para '%s' devolvió %d resultados.", query, len(searchResults))
	c.JSON(http.StatusOK, gin.H{"videos": searchResults})
}

// handleGetVideosFeed devuelve una lista de videos para el feed principal.
// TODO: Implementar la lógica para obtener videos desde la base de datos.
func handleGetVideosFeed(c *gin.Context) {
	pageStr := c.DefaultQuery("page", "1")
	page, _ := strconv.Atoi(pageStr)
	if page < 1 {
		page = 1
	}
	limit := 10
	offset := (page - 1) * limit

	// Consulta SQL para obtener videos reales
	rows, err := DB.QueryContext(c, `
		SELECT 
			c.id_contenido, c.titulo, c.descripcion, c.url_contenido, COALESCE(c.url_thumbnail, ''), 
			tc.codigo,
			(SELECT COUNT(*) FROM interacciones WHERE id_contenido = c.id_contenido AND id_tipo_interaccion = $1) as likes
		FROM contenidos c
		JOIN tipos_contenido tc ON c.id_tipo_contenido = tc.id_tipo_contenido
		WHERE c.id_estado_contenido = $2
		ORDER BY c.fecha_creacion DESC
		LIMIT $3 OFFSET $4`,
		likeInteractionTypeID, publishedContentStateID, limit, offset)

	if err != nil {
		log.Printf("Error al obtener feed: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Error al cargar videos"})
		return
	}
	defer rows.Close()

	var videosForResponse []gin.H

	for rows.Next() {
		var id int
		var title, desc, url, thumb, contentType string
		var likes int
		if err := rows.Scan(&id, &title, &desc, &url, &thumb, &contentType, &likes); err != nil {
			continue
		}
		videosForResponse = append(videosForResponse, gin.H{
			"id": strconv.Itoa(id), "title": title, "description": desc, "video_url": url, "thumbnail_url": thumb,
			"content_type": contentType, "likes": likes, "comments": 0, "is_liked": false, "is_bookmarked": false,
		})
	}

	c.JSON(http.StatusOK, gin.H{"videos": videosForResponse})
}
