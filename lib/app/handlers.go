package main

import (
	"context"
	"database/sql"
	"fmt"
	"log"
	"net/http"
	"os"
	"time"

	"github.com/cloudinary/cloudinary-go/v2/api/uploader"
	"github.com/gin-gonic/gin"
	"github.com/golang-jwt/jwt/v4"
	"golang.org/x/crypto/bcrypt"
	"google.golang.org/api/idtoken"
)

// --- Handlers ---

// handleVerifyToken es el nuevo handler para el flujo de la app nativa.
func handleVerifyToken(c *gin.Context) {
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

	// --- Lógica de Base de Datos (idéntica a la de handleGoogleCallback) ---
	var userID int
	var user User

	err = DB.QueryRowContext(c, "SELECT u.id_usuario, p.nombre, u.email, p.avatar_url FROM usuarios u JOIN perfiles p ON u.id_usuario = p.id_usuario WHERE u.email = $1", googleEmail).Scan(&userID, &user.Username, &user.Email, &user.AvatarURL)

	if err != nil {
		if err == sql.ErrNoRows {
			log.Printf("Usuario nuevo con email %s. Creando entrada en la BD.", googleEmail)
			tx, err := DB.BeginTx(c, nil)
			if err != nil {
				c.JSON(http.StatusInternalServerError, gin.H{"error": "Error al iniciar la transacción: " + err.Error()})
				return
			}
			defer tx.Rollback()

			err = tx.QueryRowContext(c, "INSERT INTO usuarios (id_tipo_usuario, id_estado_usuario, email, password_hash, fecha_registro) VALUES (3, 1, $1, 'google-login', NOW()) RETURNING id_usuario", googleEmail).Scan(&userID)
			if err != nil {
				c.JSON(http.StatusInternalServerError, gin.H{"error": "Error al crear usuario: " + err.Error()})
				return
			}

			_, err = tx.ExecContext(c, "INSERT INTO perfiles (id_usuario, nombre, apellido, avatar_url) VALUES ($1, $2, '', $3)", userID, googleName, googlePicture)
			if err != nil {
				c.JSON(http.StatusInternalServerError, gin.H{"error": "Error al crear perfil: " + err.Error()})
				return
			}

			if err = tx.Commit(); err != nil {
				c.JSON(http.StatusInternalServerError, gin.H{"error": "Error al confirmar la transacción: " + err.Error()})
				return
			}
			// No es necesario asignar user.ID aquí, ya que el token usará el userID numérico.
		} else {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Error al consultar la base de datos: " + err.Error()})
			return
		}
	} else {
		log.Printf("Usuario existente con email %s. Actualizando datos.", googleEmail)
		_, err = DB.ExecContext(c, "UPDATE usuarios SET ultimo_login = NOW() WHERE id_usuario = $1", userID)
		if err != nil {
			log.Printf("Advertencia: no se pudo actualizar ultimo_login para usuario %d: %v", userID, err)
		}
	}

	// 3. Crear nuestro propio token JWT.
	// Guardamos el userID como un número, no como un string.
	jwtToken := jwt.NewWithClaims(jwt.SigningMethodHS256, jwt.MapClaims{
		"user_id": float64(userID), // El tipo por defecto para números en claims de JWT es float64
		"exp":     time.Now().Add(time.Hour * 72).Unix(),
	})

	tokenString, err := jwtToken.SignedString([]byte(os.Getenv("JWT_SECRET_KEY")))
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create token"})
		return
	}

	// 4. Devolver nuestro token JWT en una respuesta JSON.
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

	var userID int
	var hashedPassword string

	// 1. Buscar al usuario por email y obtener su ID y hash de contraseña.
	err := DB.QueryRowContext(c, "SELECT id_usuario, password_hash FROM usuarios WHERE email = $1", requestBody.Email).Scan(&userID, &hashedPassword)
	if err != nil {
		if err == sql.ErrNoRows {
			// Email no encontrado. Devolvemos 401 para no dar pistas a atacantes.
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Credenciales inválidas"})
			return
		}
		// Otro error de base de datos.
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Error en la base de datos"})
		return
	}

	// 2. Comparar la contraseña proporcionada con el hash almacenado.
	err = bcrypt.CompareHashAndPassword([]byte(hashedPassword), []byte(requestBody.Password))
	if err != nil {
		// La contraseña no coincide.
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Credenciales inválidas"})
		return
	}

	// 3. Si la contraseña es correcta, generar un token JWT (lógica idéntica a la de Google).
	log.Printf("Usuario %d autenticado correctamente con email/password.", userID)

	jwtToken := jwt.NewWithClaims(jwt.SigningMethodHS256, jwt.MapClaims{
		"user_id": float64(userID),
		"exp":     time.Now().Add(time.Hour * 72).Unix(),
	})

	tokenString, err := jwtToken.SignedString([]byte(os.Getenv("JWT_SECRET_KEY")))
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Fallo al crear el token"})
		return
	}

	// Actualizar la fecha de último login (opcional pero buena práctica).
	_, err = DB.ExecContext(c, "UPDATE usuarios SET ultimo_login = NOW() WHERE id_usuario = $1", userID)
	if err != nil {
		log.Printf("Advertencia: no se pudo actualizar ultimo_login para usuario %d: %v", userID, err)
	}

	// 4. Devolver el token.
	c.JSON(http.StatusOK, gin.H{"token": tokenString})
}

func handleGetProfile(c *gin.Context) {
	// --- CAMBIO PARA PRUEBAS ---
	// Forzamos el uso del userID = 1 para que la pantalla de perfil siempre
	// muestre el mismo usuario durante el desarrollo, ignorando el token.
	const userID = 1
	log.Printf("ADVERTENCIA: Se está forzando el uso del userID %d para pruebas en handleGetProfile.", userID)

	var user User

	// Buscamos el perfil del usuario usando el ID de prueba (1).
	// La columna id_usuario es numérica.
	err := DB.QueryRowContext(c, "SELECT u.id_usuario, p.nombre, u.email, p.avatar_url FROM usuarios u JOIN perfiles p ON u.id_usuario = p.id_usuario WHERE u.id_usuario = $1", userID).Scan(&user.ID, &user.Username, &user.Email, &user.AvatarURL)

	user.ID = userID // Aseguramos que el ID del usuario se incluya en la respuesta.
	if err != nil {
		if err == sql.ErrNoRows {
			c.JSON(http.StatusNotFound, gin.H{"error": "User not found"})
		} else {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Database query error: " + err.Error()})
		}
		return
	}
	c.JSON(http.StatusOK, user)
}

func handleUploadAvatar(c *gin.Context) {
	// --- CAMBIO PARA PRUEBAS ---
	// Forzamos el uso del userID = 1 para que la subida de avatar siempre
	// se asocie al mismo usuario durante el desarrollo, ignorando el token.
	const userID = 1
	log.Printf("ADVERTENCIA: Se está forzando el uso del userID %d para pruebas en handleUploadAvatar.", userID)

	/* CÓDIGO DE AUTENTICACIÓN ORIGINAL (DESACTIVADO)
	userIDVal, exists := c.Get("userID") ...
	*/
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

	// 4. Actualizar la URL del avatar en la base de datos
	_, err = DB.ExecContext(c, "UPDATE perfiles SET avatar_url = $1 WHERE id_usuario = $2", uploadResult.SecureURL, userID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Fallo al actualizar la base de datos: " + err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Avatar actualizado correctamente", "avatarUrl": uploadResult.SecureURL})
}

// handleUploadVideo maneja la subida de un nuevo video.
func handleUploadVideo(c *gin.Context) {
	// --- CAMBIO PARA PRUEBAS ---
	// Forzamos el uso del userID = 1 para asociar el video al usuario de prueba.
	const userID = 1
	log.Printf("ADVERTENCIA: Se está forzando el uso del userID %d para pruebas en handleUploadVideo.", userID)

	log.Printf("Iniciando subida de video para el usuario ID: %d", userID)
	// 1. Obtener los campos de texto del formulario.
	title := c.PostForm("title")
	description := c.PostForm("description")
	if title == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "El título es requerido"})
		return
	}

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

	// 3. Subir el video a Cloudinary, especificando que es un video.
	uploadResult, err := cld.Upload.Upload(context.Background(), src, uploader.UploadParams{
		Folder:       "videos", // Guardar en una carpeta específica.
		ResourceType: "video",  // ¡Importante! Indicar que es un video.
	})
	if err != nil {
		// ¡AÑADIDO! Logueamos el error detallado de Cloudinary.
		log.Printf("ERROR: Fallo al subir el video a Cloudinary: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Fallo al subir el video a Cloudinary: " + err.Error()})
		return
	}

	// 4. Insertar la información del video en la tabla 'contenidos'.
	insertQuery := `
		INSERT INTO contenidos (id_autor, id_tipo_contenido, id_estado_contenido, titulo, descripcion, url_contenido, url_thumbnail, duracion_segundos, tamanio_bytes, fecha_publicacion)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, NOW())
	`
	// Por ahora, usamos una URL de miniatura estática.
	thumbnailURL := "https://res.cloudinary.com/dlnm7yxt3/image/upload/v1762540397/placeholder_thumbnail.jpg"

	// --- CORRECCIÓN ---
	// La duración no es un campo directo. Se extrae del mapa de respuesta genérico.
	var duration float64
	if respMap, ok := uploadResult.Response.(map[string]interface{}); ok {
		if d, ok := respMap["duration"].(float64); ok {
			duration = d
		}
	}
	// El tamaño sí es un campo directo: uploadResult.Bytes

	// Usamos los IDs globales cargados al inicio de la aplicación.
	_, err = DB.ExecContext(c, insertQuery, userID, videoContentTypeID, publishedContentStateID, title, description, uploadResult.SecureURL, thumbnailURL, int(duration), uploadResult.Bytes)
	if err != nil {

		log.Printf("ERROR: Fallo al insertar el video en la base de datos: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Fallo al guardar la información del video en la base de datos: " + err.Error()})
		return
	}

	log.Printf("Video subido por usuario %d y guardado en la base de datos.", userID)
	c.JSON(http.StatusOK, gin.H{"message": "Video subido correctamente", "videoUrl": uploadResult.SecureURL})
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
	videoID := c.Param("id")
	// ensureVideoExists ya bloquea el mutex, así que no necesitamos hacerlo aquí de nuevo.
	// Sin embargo, para mantener la lógica clara, bloquearemos el mutex durante toda la operación.
	Mu.Lock()
	defer Mu.Unlock()

	// Aseguramos que el video exista en nuestro mapa simulado.
	if _, ok := Videos[videoID]; !ok {
		Videos[videoID] = &Video{ID: videoID, Likes: 0, IsLiked: false, IsBookmarked: false}
	}
	video := Videos[videoID]

	// Modificamos el estado del video.
	video.IsLiked = !video.IsLiked
	if video.IsLiked {
		video.Likes++
	} else {
		video.Likes--
	}
	log.Printf("Video %s toggled like. New state: Liked=%v, Likes=%d", videoID, video.IsLiked, video.Likes)
	c.JSON(http.StatusOK, video)
}

func handleToggleBookmark(c *gin.Context) {
	videoID := c.Param("id")
	Mu.Lock()
	defer Mu.Unlock()

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

	// Buscamos en la base de datos videos cuyo título o descripción coincidan con la búsqueda.
	rows, err := DB.QueryContext(c, `
		SELECT
			c.id_contenido, c.titulo, c.descripcion, c.url_contenido, c.url_thumbnail,
			COALESCE(c.duracion_segundos, 0),
			(SELECT COUNT(*) FROM interacciones WHERE id_contenido = c.id_contenido AND id_tipo_interaccion = $1) AS likes_count,
			(SELECT COUNT(*) FROM comentarios WHERE id_contenido = c.id_contenido) AS comments_count
		FROM contenidos c
		WHERE
			c.id_tipo_contenido = $2 AND c.id_estado_contenido = $3
			AND (c.titulo ILIKE $4 OR c.descripcion ILIKE $4)
		ORDER BY c.fecha_publicacion DESC
	`, likeInteractionTypeID, videoContentTypeID, publishedContentStateID, searchQuery)

	if err != nil {
		log.Printf("Error al buscar videos en la base de datos: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Error al buscar videos"})
		return
	}
	defer rows.Close()

	var searchResults []gin.H
	for rows.Next() {
		var id, duration, likes, comments int
		var title, description, videoURL, thumbnailURL string
		if err := rows.Scan(&id, &title, &description, &videoURL, &thumbnailURL, &duration, &likes, &comments); err != nil {
			log.Printf("Error al escanear la fila del video de búsqueda: %v", err)
			continue
		}
		searchResults = append(searchResults, gin.H{
			"id":            fmt.Sprintf("%d", id),
			"title":         title,
			"description":   description,
			"video_url":     videoURL,
			"thumbnail_url": thumbnailURL,
			"likes":         likes,
			"comments":      comments,
			"is_liked":      false, // Estos valores podrían calcularse si el usuario está autenticado
			"is_bookmarked": false,
		})
	}

	log.Printf("Búsqueda para '%s' devolvió %d resultados.", query, len(searchResults))
	c.JSON(http.StatusOK, gin.H{"videos": searchResults})
}

// handleGetVideosFeed devuelve una lista de videos para el feed principal.
// TODO: Implementar la lógica para obtener videos desde la base de datos.
func handleGetVideosFeed(c *gin.Context) {
	// Consulta la tabla 'contenidos' y calcula likes/comentarios dinámicamente.
	rows, err := DB.QueryContext(c, `
		SELECT
			c.id_contenido,
			c.titulo,
			c.descripcion,
			c.url_contenido,
			c.url_thumbnail, -- CORRECCIÓN: Añadir la URL de la miniatura a la consulta
			COALESCE(c.duracion_segundos, 0),
			COALESCE(COUNT(DISTINCT l.id_interaccion), 0) AS likes_count,
			COALESCE(COUNT(DISTINCT comm.id_comentario), 0) AS comments_count
		FROM
			contenidos c
		LEFT JOIN
			interacciones l ON c.id_contenido = l.id_contenido AND l.id_tipo_interaccion = $1
		LEFT JOIN
			comentarios comm ON c.id_contenido = comm.id_contenido
		WHERE
			c.id_tipo_contenido = $2 AND c.id_estado_contenido = $3
		GROUP BY
			c.id_contenido, c.titulo, c.descripcion, c.url_contenido, c.url_thumbnail, c.duracion_segundos, c.fecha_publicacion
		ORDER BY
			c.fecha_publicacion DESC;
	`, likeInteractionTypeID, videoContentTypeID, publishedContentStateID)
	if err != nil {
		log.Printf("Error al consultar videos desde la base de datos: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Error al obtener los videos"})
		return
	}
	defer rows.Close()

	var videosForResponse []gin.H
	for rows.Next() {
		var id, duration, likes, comments int
		var title, description, videoURL, thumbnailURL string // CORRECCIÓN: Añadir variable para la miniatura
		if err := rows.Scan(&id, &title, &description, &videoURL, &thumbnailURL, &duration, &likes, &comments); err != nil {
			log.Printf("Error al escanear la fila del video: %v", err)
			continue // Salta este video si hay un error y continúa con el siguiente
		}

		videosForResponse = append(videosForResponse, gin.H{
			"id":            fmt.Sprintf("%d", id), // El ID ahora viene de la BD
			"title":         title,                 // Agregamos el título
			"description":   description,           // La descripción del contenido
			"video_url":     videoURL,
			"thumbnail_url": thumbnailURL, // CORRECCIÓN: Incluir la URL de la miniatura en la respuesta
			"likes":         likes,
			"comments":      comments,
			"is_liked":      false,
			"is_bookmarked": false,
		})
	}

	c.JSON(http.StatusOK, gin.H{"videos": videosForResponse})
}
