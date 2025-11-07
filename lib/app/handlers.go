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

func handleGetProfile(c *gin.Context) {
	// El userID del middleware ahora viene como float64.
	userIDVal, exists := c.Get("userID")
	if !exists {
		// Esto no debería ocurrir si el middleware funciona, pero es una buena práctica verificar.
		c.JSON(http.StatusUnauthorized, gin.H{"error": "UserID no encontrado en el token"})
		return
	}
	// Convertimos el float64 a int para usarlo en la consulta.
	userID := int(userIDVal.(float64))

	var user User

	// Buscamos el perfil del usuario usando el ID del token JWT
	// La columna id_usuario es numérica, por lo que pasamos el userID como int.
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
	// El userID del middleware ahora viene como float64.
	userIDVal, exists := c.Get("userID")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "UserID no encontrado en el token"})
		return
	}
	// Convertimos el float64 a int.
	userID := int(userIDVal.(float64))

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
	uploadResult, err := cld.Upload.Upload(c.Request.Context(), src, uploader.UploadParams{
		PublicID:  fmt.Sprintf("avatars/%d", userID),
		Overwrite: &overwrite, // Pasamos el puntero a la variable 'overwrite'
	})
	if err != nil {
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

	// En una app real, aquí buscarías en tu base de datos de videos.
	// Por ahora, devolvemos un resultado simulado.
	log.Printf("Buscando videos para: '%s'", query)
	c.JSON(http.StatusOK, gin.H{
		"message": "Search results for " + query,
		"results": []gin.H{
			{"id": "search1", "description": "Video encontrado sobre " + query},
		},
	})
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
