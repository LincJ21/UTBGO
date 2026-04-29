package main

import (
	"context"
	"encoding/json"
	"fmt"
	"html"
	"net/http"
	"strconv"
	"strings"
	"time"

	"database/sql"

	"github.com/gin-gonic/gin"
	"github.com/golang-jwt/jwt/v4"
)

// --- Funciones de Ayuda (Refactorización) ---

// getOrCreateUser busca un usuario por email. Si no existe, lo crea junto con su perfil.
// roleCode debe venir ya resuelto por la política de autenticación correspondiente.
func getOrCreateUser(ctx context.Context, email, name, picture, roleCode string) (int, error) {
	email = strings.ToLower(strings.TrimSpace(email))
	name = strings.TrimSpace(name)
	var userID int

	// Intenta encontrar al usuario existente.
	var currentRoleID int
	var currentRoleCode string
	err := DB.QueryRowContext(ctx, `
		SELECT u.id_usuario, u.id_tipo_usuario, tu.codigo
		FROM usuarios u
		JOIN tipos_usuario tu ON tu.id_tipo_usuario = u.id_tipo_usuario
		WHERE LOWER(u.email) = LOWER($1)`, email).Scan(&userID, &currentRoleID, &currentRoleCode)
	if err == nil {
		Logger.Info("Usuario existente encontrado", "email", email)

		// Mantener roles administrativos asignados manualmente.
		var targetRoleID int
		err = DB.QueryRowContext(ctx, "SELECT id_tipo_usuario FROM tipos_usuario WHERE codigo = $1", roleCode).Scan(&targetRoleID)
		if err == nil && targetRoleID != currentRoleID &&
			currentRoleCode != RoleAdmin && currentRoleCode != RoleModerador {
			Logger.Info("Actualizando rol de usuario existente",
				"email", email,
				"old_role", currentRoleCode,
				"new_role", roleCode,
			)
			_, _ = DB.ExecContext(ctx, "UPDATE usuarios SET id_tipo_usuario = $1 WHERE id_usuario = $2", targetRoleID, userID)
		}

		// Invalidar caché SIEMPRE al iniciar sesión para asegurar datos frescos
		if Cache != nil {
			Cache.InvalidateProfile(ctx, userID)
		}

		_, updateErr := DB.ExecContext(ctx, "UPDATE usuarios SET ultimo_login = NOW() WHERE id_usuario = $1", userID)
		if updateErr != nil {
			Logger.Warn("No se pudo actualizar ultimo_login", "user_id", userID, "error", updateErr)
		}
		return userID, nil
	}

	// Si el error no es "no rows", es un error inesperado.
	if err != sql.ErrNoRows {
		return 0, fmt.Errorf("error al consultar la base de datos: %w", err)
	}

	Logger.Info("Creando usuario nuevo", "email", email)
	tx, err := DB.BeginTx(ctx, nil)
	if err != nil {
		return 0, fmt.Errorf("error al iniciar la transacción: %w", err)
	}
	defer tx.Rollback() // Se ejecuta si el Commit() no se alcanza.

	var roleTypeID int
	err = tx.QueryRowContext(ctx, "SELECT id_tipo_usuario FROM tipos_usuario WHERE codigo = $1", roleCode).Scan(&roleTypeID)
	if err != nil {
		// Fallback por si acaso el rol no existe en tipos_usuario
		tx.QueryRowContext(ctx, "SELECT id_tipo_usuario FROM tipos_usuario WHERE codigo = 'estudiante'").Scan(&roleTypeID)
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
	err = tx.QueryRowContext(ctx, "INSERT INTO usuarios (id_tipo_usuario, id_estado_usuario, email, password_hash, fecha_registro) VALUES ($1, $2, $3, 'google-login', NOW()) RETURNING id_usuario", roleTypeID, activeStateID, email).Scan(&userID)
	if err != nil {
		if strings.Contains(err.Error(), "usuarios_id_usuario_fkey") {
			Logger.Error("ERROR DE BD: restricciones incorrectas. Ejecuta fix_constraints.sql")
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

	// Invalidar caché del perfil inmediatamente para asegurar que el rol correcto se cargue
	if Cache != nil {
		Cache.InvalidateProfile(ctx, userID)
	}

	return userID, nil
}

// generateJWT crea un token JWT para un ID de usuario específico.
// NOTA: Para nuevos flujos, usar Auth.GenerateTokenPair() que incluye refresh token.
func generateJWT(userID int) (string, error) {
	jwtToken := jwt.NewWithClaims(jwt.SigningMethodHS256, jwt.MapClaims{
		"user_id": float64(userID),
		"type":    "access",
		"exp":     time.Now().Add(time.Hour * 1).Unix(), // 1 hora (consistente con AuthService)
		"iat":     time.Now().Unix(),
	})

	return jwtToken.SignedString([]byte(JWT_SECRET_KEY))
}

// --- Handlers ---

// handleVerifyToken es el handler para el flujo de la app nativa.
func handleVerifyToken(c *gin.Context) {
	RespondError(c, ErrForbidden(
		"Este flujo fue deshabilitado. Los aspirantes deben iniciar con Google desde la app usando un correo @gmail.com",
	))
}

// handleLogin ELIMINADO: era código muerto con auth bypass (userID=1 hardcodeado).
// Usar handleLoginV2 en /api/v1/auth/login para login seguro con bcrypt.

func handleGetMyPublications(c *gin.Context) {
	userIDVal, exists := c.Get("userID")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "No autenticado"})
		return
	}
	userID := int(userIDVal.(float64))

	videos, err := Repos.Videos.GetByAuthor(c.Request.Context(), userID, &userID)
	if err != nil {
		Logger.Error("Error al obtener publicaciones del autor", "error", err, "author_id", userID)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Fallo al cargar las publicaciones"})
		return
	}

	if videos == nil {
		videos = []Video{}
	}
	c.JSON(http.StatusOK, videos)
}

func handleGetPublicProfile(c *gin.Context) {
	// Obtenemos el userID del contexto ("Requester")
	requesterIDVal, exists := c.Get("userID")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "No autenticado"})
		return
	}
	requesterID := int(requesterIDVal.(float64))

	// Obtenemos el userID que quiere visitar ("Target")
	targetIDStr := c.Param("id")
	targetID, err := strconv.Atoi(targetIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "ID de usuario inválido"})
		return
	}

	// 1. Obtener información del Target
	targetProfile, err := Repos.Profiles.GetPublicProfile(c.Request.Context(), targetID, &requesterID)
	if err != nil {
		Logger.Error("Error al obtener perfil público", "error", err, "target_id", targetID)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Falló al cargar perfil target"})
		return
	}
	if targetProfile == nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Perfil no encontrado"})
		return
	}

	// 2. Si son el mismo usuario, dejar pasar directamente
	if requesterID == targetID {
		c.JSON(http.StatusOK, targetProfile)
		return
	}

	// 3. Obtener el Rol del Requester para la matriz de reglas
	requesterUser, err := Repos.Users.FindByID(c.Request.Context(), requesterID)
	if err != nil || requesterUser == nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Usuario requiriente no válido"})
		return
	}
	allowed, denialMessage := canViewPublicProfile(requesterUser.Role, targetProfile.Role)
	if !allowed {
		c.JSON(http.StatusForbidden, gin.H{"error": denialMessage})
		return
	}

	c.JSON(http.StatusOK, targetProfile)
}

func canViewPublicProfile(requesterRole, targetRole string) (bool, string) {
	if requesterRole == "admin" {
		return true, ""
	}

	if targetRole == "admin" {
		return false, "No tienes permisos corporativos para ver este perfil."
	}

	if requesterRole == "aspirante" {
		if targetRole == "profesor" {
			return true, ""
		}
		return false, "Los aspirantes solo pueden ver perfiles publicos de docentes."
	}

	return true, ""
}

// invalidateProfileCaches refresca los perfiles afectados por cambios relacionales
// como follow/unfollow para evitar followers y stats obsoletos.
func invalidateProfileCaches(ctx context.Context, userIDs ...int) {
	if Cache == nil {
		return
	}

	for _, userID := range userIDs {
		if userID <= 0 {
			continue
		}
		Cache.InvalidateProfile(ctx, userID)
	}
}

func handleFollowUser(c *gin.Context) {
	followerIDVal, exists := c.Get("userID")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "No autenticado"})
		return
	}
	followerID := int(followerIDVal.(float64))

	targetIDStr := c.Param("id")
	targetID, err := strconv.Atoi(targetIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "ID de usuario inválido"})
		return
	}

	err = Repos.Profiles.FollowUser(c.Request.Context(), followerID, targetID)
	if err != nil {
		Logger.Error("Error al seguir usuario", "error", err, "follower", followerID, "followed", targetID)
		if err.Error() == "el usuario no puede seguirse a sí mismo" {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Falló al seguir usuario"})
		return
	}

	invalidateProfileCaches(c.Request.Context(), followerID, targetID)

	c.JSON(http.StatusOK, gin.H{"message": "Usuario seguido exitosamente"})
}

func handleUnfollowUser(c *gin.Context) {
	followerIDVal, exists := c.Get("userID")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "No autenticado"})
		return
	}
	followerID := int(followerIDVal.(float64))

	targetIDStr := c.Param("id")
	targetID, err := strconv.Atoi(targetIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "ID de usuario inválido"})
		return
	}

	err = Repos.Profiles.UnfollowUser(c.Request.Context(), followerID, targetID)
	if err != nil {
		Logger.Error("Error al dejar de seguir usuario", "error", err, "follower", followerID, "followed", targetID)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Falló al dejar de seguir usuario"})
		return
	}

	invalidateProfileCaches(c.Request.Context(), followerID, targetID)

	c.JSON(http.StatusOK, gin.H{"message": "Has dejado de seguir al usuario"})
}

func handleGetPublicPublications(c *gin.Context) {
	// Reutilizamos la misma matriz de seguridad básica que el perfil.
	requesterIDVal, exists := c.Get("userID")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "No autenticado"})
		return
	}
	requesterID := int(requesterIDVal.(float64))

	targetIDStr := c.Param("id")
	targetID, err := strconv.Atoi(targetIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "ID de usuario inválido"})
		return
	}

	requesterUser, err := Repos.Users.FindByID(c.Request.Context(), requesterID)
	if err != nil || requesterUser == nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Usuario requiriente no válido"})
		return
	}

	if requesterID != targetID {
		targetUser, err := Repos.Users.FindByID(c.Request.Context(), targetID)
		if err != nil {
			Logger.Error("Error al obtener usuario target", "error", err, "target_id", targetID)
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Fallo al cargar las publicaciones"})
			return
		}
		if targetUser == nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "Perfil no encontrado"})
			return
		}

		allowed, denialMessage := canViewPublicProfile(requesterUser.Role, targetUser.Role)
		if !allowed {
			c.JSON(http.StatusForbidden, gin.H{"error": denialMessage})
			return
		}
	}

	videos, err := Repos.Videos.GetPublicByAuthor(c.Request.Context(), targetID)
	if err != nil {
		Logger.Error("Error al obtener publicaciones publicas", "error", err, "target_id", targetID)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Fallo al cargar las publicaciones"})
		return
	}

	if videos == nil {
		videos = []PublicVideo{}
	}
	c.JSON(http.StatusOK, videos)
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

	// Intentar obtener del caché
	if Cache != nil {
		if cached, found := Cache.GetProfile(c.Request.Context(), userID); found {
			c.JSON(http.StatusOK, cached)
			return
		}
	}

	var user User
	var avatarURL sql.NullString     // Manejar valores nulos de SQL
	var interestsJSON sql.NullString // Arreglo PostgreSQL convertido a JSON
	var bio, faculty, cvlac, website sql.NullString

	// Consultar datos reales de la base de datos (incluye rol e intereses)
	// Usamos array_to_json(p.intereses) puro para evitar anidación
	err := DB.QueryRowContext(c, `
		SELECT u.id_usuario, p.nombre || ' ' || p.apellido, u.email, p.avatar_url, tu.codigo,
		       array_to_json(p.intereses), p.biografia, p.facultad, p.cvlac_url, p.website_url
		FROM usuarios u
		JOIN perfiles p ON u.id_usuario = p.id_usuario
		JOIN tipos_usuario tu ON u.id_tipo_usuario = tu.id_tipo_usuario
		WHERE u.id_usuario = $1`, userID).Scan(
		&user.ID, &user.Username, &user.Email, &avatarURL, &user.Role, &interestsJSON,
		&bio, &faculty, &cvlac, &website)

	if err != nil {
		Logger.Error("Error al obtener perfil", "error", err, "user_id", userID)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Error al obtener perfil"})
		return
	}

	if avatarURL.Valid {
		user.AvatarURL = avatarURL.String
	}
	if bio.Valid {
		user.Bio = bio.String
	}
	if faculty.Valid {
		user.Faculty = faculty.String
	}
	if cvlac.Valid {
		user.CvlacURL = cvlac.String
	}
	if website.Valid {
		user.WebsiteURL = website.String
	}

	if interestsJSON.Valid && interestsJSON.String != "null" {
		var interests []string
		if err := json.Unmarshal([]byte(interestsJSON.String), &interests); err == nil {
			user.Interests = interests
		} else {
			Logger.Warn("Error al deserializar intereses JSON", "json", interestsJSON.String, "error", err)
		}
	} else {
		user.Interests = []string{}
	}

	// Obtener métricas transaccionales
	followers, totalLikes, totalViews, totalVideos, errStats := Repos.Profiles.GetUserStats(c.Request.Context(), userID)
	if errStats == nil {
		user.FollowersCount = followers
		user.TotalLikesReceived = totalLikes
		user.TotalViews = totalViews
		user.TotalVideos = totalVideos
	} else {
		Logger.Warn("No se pudieron cargar estadisticas del usuario", "user_id", userID, "error", errStats)
	}

	// Guardar en caché (Ahora incluye el campo Role, Interests y Stats en el struct User)
	if Cache != nil {
		Cache.SetProfile(c.Request.Context(), userID, user)
	}

	c.JSON(http.StatusOK, user)
}

func handleUpdateProfile(c *gin.Context) {
	userIDVal, exists := c.Get("userID")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "User not authenticated"})
		return
	}
	userID := int(userIDVal.(float64))

	var req UpdateProfileRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Datos inválidos: " + err.Error()})
		return
	}

	// Sanitización básica
	req.Name = html.EscapeString(strings.TrimSpace(req.Name))
	req.Bio = html.EscapeString(strings.TrimSpace(req.Bio))
	req.Faculty = html.EscapeString(strings.TrimSpace(req.Faculty))
	req.CvlacURL = strings.TrimSpace(req.CvlacURL)
	req.WebsiteURL = strings.TrimSpace(req.WebsiteURL)

	profileReq := &Profile{
		UserID:     userID,
		Name:       req.Name,
		Bio:        req.Bio,
		Faculty:    req.Faculty,
		CvlacURL:   req.CvlacURL,
		WebsiteURL: req.WebsiteURL,
	}

	repo := NewPostgresProfileRepository()
	err := repo.UpdateProfile(c.Request.Context(), profileReq)
	if err != nil {
		Logger.Error("Error al actualizar perfil", "error", err, "user_id", userID)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "No se pudo actualizar el perfil"})
		return
	}

	// Invalidar caché
	if Cache != nil {
		// No existe DeleteProfile en cache.go, pero Get/Set sobrescribirán, o ignoramos porque Cache.SetProfile se llama en GET
		// Lo ideal es vaciar la llave o sobreescribir
		// Por ahora simplemente dejamos que espere a expirar, o si existiese Delete usarlo.
		// Ya que la BD se actualizó, en el próximo login/GET se cargará.
	}

	c.JSON(http.StatusOK, gin.H{"message": "Perfil actualizado correctamente"})
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
		c.JSON(http.StatusBadRequest, gin.H{"error": "No se ha subido ningún archivo"})
		return
	}

	// 2. Abrir el archivo para leerlo
	src, err := file.Open()
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "No se pudo abrir el archivo"})
		return
	}
	defer src.Close()

	// Subir el archivo a Azure Blob Storage.
	result, err := Storage.UploadImage(c.Request.Context(), src, "avatars", fmt.Sprintf("%d", userID), true)
	if err != nil {
		Logger.Error("Fallo al subir avatar a Azure", "error", err, "user_id", userID)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Fallo al subir el avatar"})
		return
	}

	_, err = DB.ExecContext(c, "UPDATE perfiles SET avatar_url = $1 WHERE id_usuario = $2", result.URL, userID)
	if err != nil {
		Logger.Error("Error al actualizar avatar en BD", "error", err, "user_id", userID)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Avatar subido pero no guardado en BD"})
		return
	}

	// Invalidar caché del perfil
	if Cache != nil {
		Cache.InvalidateProfile(c.Request.Context(), userID)
	}

	c.JSON(http.StatusOK, gin.H{"message": "Avatar actualizado correctamente", "avatarUrl": result.URL})
}

// handleUploadVideo maneja la subida de un nuevo video.
func handleUploadVideo(c *gin.Context) {
	// Obtenemos el userID del contexto, establecido por el AuthMiddleware.
	userIDVal, exists := c.Get("userID")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "User not authenticated"})
		return
	}
	userID := int(userIDVal.(float64))

	Logger.Info("Iniciando subida de video", "user_id", userID)
	title := c.PostForm("title")
	description := c.PostForm("description")
	if title == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "El título es requerido"})
		return
	}

	// 2. Obtener el archivo de video.
	file, err := c.FormFile("video")
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "No se ha subido ningún archivo de video"})
		return
	}

	// HAL-017: Validar archivo (tamaño + MIME type) — misma seguridad que v2
	validator := NewFileValidator()
	if apiErr := validator.ValidateVideo(file); apiErr != nil {
		c.JSON(apiErr.HTTPStatus, gin.H{"error": apiErr.Message})
		return
	}

	src, err := file.Open()
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "No se pudo abrir el archivo de video"})
		return
	}
	defer src.Close()

	// 3. Subir el video a Azure Blob Storage usando la interfaz StorageProvider.
	result, err := Storage.UploadVideo(c.Request.Context(), src, "videos")
	if err != nil {
		Logger.Error("Fallo al subir video a Azure", "error", err, "user_id", userID)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Fallo al subir el video"})
		return
	}

	// Insertar video en la base de datos
	var videoID int
	err = DB.QueryRowContext(c, `
		INSERT INTO contenidos (titulo, descripcion, id_autor, id_tipo_contenido, id_estado_contenido, url_contenido, url_thumbnail)
		VALUES ($1, $2, $3, $4, $5, $6, $7) RETURNING id_contenido`,
		title, description, userID, videoContentTypeID, publishedContentStateID, result.URL, result.URL,
	).Scan(&videoID)
	if err != nil {
		Logger.Error("Error al guardar video en BD", "error", err, "user_id", userID)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Video subido pero falló el registro en BD"})
		return
	}

	Logger.Info("Video subido exitosamente", "video_id", videoID, "user_id", userID)
	c.JSON(http.StatusOK, gin.H{"message": "Video subido correctamente", "videoUrl": result.URL})
}

// handleToggleLike maneja el toggle de like en un video
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
			Logger.Error("Error al dar like", "error", err, "user_id", userID, "video_id", videoID)
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Error al procesar like"})
			return
		}
		isLiked = true
	} else if err == nil {
		// Existe, eliminar like
		_, err = DB.ExecContext(c, "DELETE FROM interacciones WHERE id_interaccion = $1", interactionID)
		if err != nil {
			Logger.Error("Error al quitar like", "error", err, "user_id", userID, "video_id", videoID)
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Error al procesar like"})
			return
		}
		isLiked = false
	} else {
		Logger.Error("Error al consultar interacción", "error", err)
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

	// Verificar si ya existe el bookmark en la tabla favoritos
	var favoriteID int
	err = DB.QueryRowContext(c, "SELECT id_favorito FROM favoritos WHERE id_usuario = $1 AND id_contenido = $2", userID, videoID).Scan(&favoriteID)

	isBookmarked := false
	if err == sql.ErrNoRows {
		// No existe, crear bookmark
		_, err = DB.ExecContext(c, "INSERT INTO favoritos (id_usuario, id_contenido, carpeta) VALUES ($1, $2, 'guardados')", userID, videoID)
		if err != nil {
			Logger.Error("Error al guardar bookmark", "error", err)
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Error al guardar bookmark"})
			return
		}
		isBookmarked = true
	} else if err == nil {
		// Existe, eliminar bookmark
		_, err = DB.ExecContext(c, "DELETE FROM favoritos WHERE id_favorito = $1", favoriteID)
		if err != nil {
			Logger.Error("Error al quitar bookmark", "error", err)
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Error al quitar bookmark"})
			return
		}
		isBookmarked = false
	} else {
		Logger.Error("Error al consultar favoritos", "error", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Error de base de datos"})
		return
	}

	Logger.Info("Bookmark toggled", "video_id", videoIDStr, "user_id", userID, "is_bookmarked", isBookmarked)
	c.JSON(http.StatusOK, gin.H{
		"id":           videoIDStr,
		"isBookmarked": isBookmarked,
	})
}

// handleToggleRepost maneja el toggle de repost en un video
func handleToggleRepost(c *gin.Context) {
	userIDVal, exists := c.Get("userID")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "User not authenticated"})
		return
	}
	userID := int(userIDVal.(float64))

	ctx, cancel := context.WithTimeout(c.Request.Context(), 5*time.Second)
	defer cancel()

	// Validar rol de aspirante
	user, err := Repos.Admin.GetUserByID(ctx, userID)
	if err != nil || user == nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Error verificando rol de usuario"})
		return
	}
	if user.RoleCode == "aspirante" {
		c.JSON(http.StatusForbidden, gin.H{"error": "Los aspirantes no pueden repostear contenido"})
		return
	}

	videoIDStr := c.Param("id")
	videoID, err := strconv.Atoi(videoIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "ID de video inválido"})
		return
	}

	// Verificar si ya existe el repost en la base de datos
	var interactionID int
	err = DB.QueryRowContext(ctx, "SELECT id_interaccion FROM interacciones WHERE id_usuario = $1 AND id_contenido = $2 AND id_tipo_interaccion = $3", userID, videoID, repostInteractionTypeID).Scan(&interactionID)

	isReposted := false
	if err == sql.ErrNoRows {
		// No existe, crear repost
		_, err = DB.ExecContext(ctx, "INSERT INTO interacciones (id_usuario, id_contenido, id_tipo_interaccion) VALUES ($1, $2, $3)", userID, videoID, repostInteractionTypeID)
		if err != nil {
			Logger.Error("Error al dar repost", "error", err, "user_id", userID, "video_id", videoID)
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Error al procesar repost"})
			return
		}
		isReposted = true
	} else if err == nil {
		// Existe, eliminar repost
		_, err = DB.ExecContext(ctx, "DELETE FROM interacciones WHERE id_interaccion = $1", interactionID)
		if err != nil {
			Logger.Error("Error al quitar repost", "error", err, "user_id", userID, "video_id", videoID)
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Error al procesar repost"})
			return
		}
		isReposted = false
	} else {
		Logger.Error("Error al consultar interacción repost", "error", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Error de base de datos"})
		return
	}

	// Invalidar caché del perfil si estuviera
	if Cache != nil {
		Cache.InvalidateProfile(ctx, userID)
	}

	c.JSON(http.StatusOK, gin.H{
		"id":         videoIDStr,
		"isReposted": isReposted,
	})
}

// handleGetReposts devuelve los videos reposteados por el usuario
func handleGetReposts(c *gin.Context) {
	userIDVal, exists := c.Get("userID")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "User not authenticated"})
		return
	}
	userID := int(userIDVal.(float64))

	ctx, cancel := context.WithTimeout(c.Request.Context(), 10*time.Second)
	defer cancel()

	limit := 20
	offset := 0

	query := `
		SELECT 
			c.id_contenido, c.titulo, COALESCE(c.descripcion, ''), c.url_contenido, COALESCE(c.url_thumbnail, ''), 
			tc.codigo as content_type,
			COALESCE(p.nombre || ' ' || COALESCE(p.apellido, ''), 'Usuario UTB') as author_name,
			c.id_autor,
			COALESCE((SELECT TRUE FROM interacciones WHERE id_usuario = $1 AND id_contenido = c.id_contenido AND id_tipo_interaccion = $3 LIMIT 1), FALSE) as is_liked,
			COALESCE((SELECT TRUE FROM favoritos WHERE id_usuario = $1 AND id_contenido = c.id_contenido LIMIT 1), FALSE) as is_bookmarked,
			TRUE as is_reposted
		FROM interacciones i
		JOIN contenidos c ON i.id_contenido = c.id_contenido
		JOIN tipos_contenido tc ON c.id_tipo_contenido = tc.id_tipo_contenido
		LEFT JOIN perfiles p ON c.id_autor = p.id_usuario
		WHERE i.id_usuario = $1 AND i.id_tipo_interaccion = $2 AND c.id_estado_contenido = $4
		ORDER BY i.fecha_creacion DESC
		LIMIT $5 OFFSET $6
	`
	rows, err := DB.QueryContext(ctx, query, userID, repostInteractionTypeID, likeInteractionTypeID, publishedContentStateID, limit, offset)
	if err != nil {
		Logger.Error("Error listando reposts", "error", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Error al obtener reposts"})
		return
	}
	defer rows.Close()

	var videos []Video
	for rows.Next() {
		var v Video
		var contentType string
		err := rows.Scan(
			&v.ID, &v.Title, &v.Description, &v.VideoURL, &v.ThumbnailURL,
			&contentType, &v.AuthorName, &v.AuthorID,
			&v.IsLiked, &v.IsBookmarked, &v.IsReposted,
		)
		if err != nil {
			Logger.Warn("Error escaneando repost", "error", err)
			continue
		}
		videos = append(videos, v)
	}

	if videos == nil {
		videos = []Video{}
	}

	c.JSON(http.StatusOK, videos)
}

func handleGetComments(c *gin.Context) {
	videoIDStr := c.Param("id")
	videoID, err := strconv.Atoi(videoIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "ID de video inválido"})
		return
	}

	// Obtener comentarios desde la base de datos
	rows, err := DB.QueryContext(c, `
		SELECT c.id_comentario, c.texto, c.fecha_creacion, 
		       u.id_usuario, COALESCE(p.nombre || ' ' || p.apellido, u.email) as username,
		       COALESCE(p.avatar_url, '') as avatar_url
		FROM comentarios c
		JOIN usuarios u ON c.id_usuario = u.id_usuario
		LEFT JOIN perfiles p ON u.id_usuario = p.id_usuario
		WHERE c.id_contenido = $1 AND c.id_estado_general = $2
		ORDER BY c.fecha_creacion DESC
		LIMIT 50`, videoID, activeCommentStateID)

	if err != nil {
		Logger.Error("Error al obtener comentarios", "error", err, "video_id", videoID)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Error al cargar comentarios"})
		return
	}
	defer rows.Close()

	var comments []gin.H
	for rows.Next() {
		var commentID, userID int
		var text, username, avatarURL string
		var createdAt time.Time
		if err := rows.Scan(&commentID, &text, &createdAt, &userID, &username, &avatarURL); err != nil {
			continue
		}
		comments = append(comments, gin.H{
			"id":        strconv.Itoa(commentID),
			"userId":    strconv.Itoa(userID),
			"username":  username,
			"text":      text,
			"avatarUrl": avatarURL,
			"createdAt": createdAt.Format(time.RFC3339),
		})
	}

	if comments == nil {
		comments = []gin.H{} // Devolver array vacío en lugar de null
	}

	c.JSON(http.StatusOK, comments)
}

func handleGetConnections(c *gin.Context) {
	// 1. Quién pide
	var requesterID *int
	if userIDVal, exists := c.Get("userID"); exists {
		id := int(userIDVal.(float64))
		requesterID = &id
	}

	// 2. De quién lo pide
	targetIDStr := c.Param("id")
	targetID, err := strconv.Atoi(targetIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "ID de usuario inválido"})
		return
	}

	// 3. Consultar DB
	connections, err := Repos.Profiles.GetConnections(c.Request.Context(), targetID, requesterID)
	if err != nil {
		Logger.Error("Error al obtener conexiones", "error", err, "target", targetID)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "No se pudieron obtener las conexiones"})
		return
	}

	c.JSON(http.StatusOK, connections)
}

// handleCreateComment crea un nuevo comentario en un video
func handleCreateComment(c *gin.Context) {
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

	var requestBody struct {
		Text string `json:"text" binding:"required,min=1,max=1000"`
	}
	if err := c.ShouldBindJSON(&requestBody); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "El texto del comentario es requerido (máx 1000 caracteres)"})
		return
	}

	// Sanitizar texto: escapar HTML para prevenir XSS almacenado (HAL-015)
	text := html.EscapeString(strings.TrimSpace(requestBody.Text))
	if len(text) == 0 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "El comentario no puede estar vacío"})
		return
	}

	// Insertar comentario en la base de datos
	var commentID int
	err = DB.QueryRowContext(c, `
		INSERT INTO comentarios (id_usuario, id_contenido, texto, id_estado_general)
		VALUES ($1, $2, $3, $4) RETURNING id_comentario`,
		userID, videoID, text, activeCommentStateID).Scan(&commentID)

	if err != nil {
		Logger.Error("Error al crear comentario", "error", err, "user_id", userID, "video_id", videoID)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Error al guardar el comentario"})
		return
	}

	Logger.Info("Comentario creado", "comment_id", commentID, "user_id", userID, "video_id", videoID)
	c.JSON(http.StatusCreated, gin.H{
		"id":      strconv.Itoa(commentID),
		"message": "Comentario creado exitosamente",
	})
}

func handleSearchVideos(c *gin.Context) {
	query := c.Query("q")
	if query == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Query parameter 'q' is required"})
		return
	}

	// Validar longitud de búsqueda
	if len(query) > 100 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "La búsqueda es demasiado larga (máx 100 caracteres)"})
		return
	}

	// Preparamos el término de búsqueda para usar con ILIKE en SQL (case-insensitive)
	searchQuery := "%" + strings.ToLower(query) + "%"

	// Búsqueda real en la base de datos con información de autor
	rows, err := DB.QueryContext(c, `
		SELECT 
			c.id_contenido, c.titulo, c.descripcion, c.url_contenido, COALESCE(c.url_thumbnail, ''),
			(SELECT COUNT(*) FROM interacciones WHERE id_contenido = c.id_contenido AND id_tipo_interaccion = $1) as likes,
			COALESCE(p.nombre || ' ' || COALESCE(p.apellido, ''), 'Usuario UTB') as author_name,
			c.id_autor
		FROM contenidos c
		LEFT JOIN perfiles p ON c.id_autor = p.id_usuario
		WHERE c.id_estado_contenido = $2 
		  AND (LOWER(c.titulo) LIKE $3 OR LOWER(c.descripcion) LIKE $3)
		ORDER BY c.fecha_creacion DESC
		LIMIT 20`,
		likeInteractionTypeID, publishedContentStateID, searchQuery)

	if err != nil {
		Logger.Error("Error en búsqueda", "error", err, "query", query)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Error al buscar videos"})
		return
	}
	defer rows.Close()

	var searchResults []gin.H
	for rows.Next() {
		var id, authorID int
		var title, desc, url, thumb, authorName string
		var likes int
		if err := rows.Scan(&id, &title, &desc, &url, &thumb, &likes, &authorName, &authorID); err != nil {
			continue
		}
		searchResults = append(searchResults, gin.H{
			"id":            strconv.Itoa(id),
			"title":         title,
			"description":   desc,
			"video_url":     url,
			"thumbnail_url": thumb,
			"likes":         likes,
			"author_name":   authorName,
			"author_id":     authorID,
		})
	}

	if searchResults == nil {
		searchResults = []gin.H{}
	}

	Logger.Info("Búsqueda realizada", "query", query, "results", len(searchResults))
	c.JSON(http.StatusOK, gin.H{"videos": searchResults})
}

// handleGetVideosFeed devuelve una lista de contenidos para el feed principal.
func handleGetVideosFeed(c *gin.Context) {
	pageStr := c.DefaultQuery("page", "1")
	page, _ := strconv.Atoi(pageStr)
	if page < 1 {
		page = 1
	}
	limit := 10
	offset := (page - 1) * limit

	// Obtener userID si está autenticado para las banderas personalizadas
	idForFlags := 0
	if idVal, exists := c.Get("userID"); exists {
		idForFlags = int(idVal.(float64))
	}

	// Consulta SQL para obtener contenidos reales con su tipo, autor e interacciones personales
	rows, err := DB.QueryContext(c, `
		SELECT 
			c.id_contenido, c.titulo, COALESCE(c.descripcion, ''), c.url_contenido, COALESCE(c.url_thumbnail, ''),
			tc.codigo as content_type,
			(SELECT COUNT(*) FROM interacciones WHERE id_contenido = c.id_contenido AND id_tipo_interaccion = $1) as likes,
			COALESCE(p.nombre || ' ' || COALESCE(p.apellido, ''), 'Usuario UTB') as author_name,
			c.id_autor,
			COALESCE((SELECT TRUE FROM interacciones WHERE id_usuario = $5 AND id_contenido = c.id_contenido AND id_tipo_interaccion = $1 LIMIT 1), FALSE) as is_liked,
			COALESCE((SELECT TRUE FROM favoritos WHERE id_usuario = $5 AND id_contenido = c.id_contenido LIMIT 1), FALSE) as is_bookmarked
		FROM contenidos c
		JOIN tipos_contenido tc ON c.id_tipo_contenido = tc.id_tipo_contenido
		LEFT JOIN perfiles p ON c.id_autor = p.id_usuario
		WHERE c.id_estado_contenido = $2
		ORDER BY c.fecha_creacion DESC
		LIMIT $3 OFFSET $4`,
		likeInteractionTypeID, publishedContentStateID, limit, offset, idForFlags)

	if err != nil {
		Logger.Error("Error al obtener feed", "error", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Error al cargar contenidos"})
		return
	}
	defer rows.Close()

	var videosForResponse []gin.H

	for rows.Next() {
		var id, authorID int
		var title, desc, url, thumb, contentType, authorName string
		var likes int
		var isLiked, isBookmarked bool
		if err := rows.Scan(&id, &title, &desc, &url, &thumb, &contentType, &likes, &authorName, &authorID, &isLiked, &isBookmarked); err != nil {
			continue
		}
		videosForResponse = append(videosForResponse, gin.H{
			"id":            id,
			"title":         title,
			"description":   desc,
			"video_url":     url,
			"thumbnail_url": thumb,
			"content_type":  contentType,
			"likes":         likes,
			"comments":      0,
			"is_liked":      isLiked,
			"is_bookmarked": isBookmarked,
			"author_name":   authorName,
			"author_id":     authorID,
		})
	}

	c.JSON(http.StatusOK, gin.H{"videos": videosForResponse})
}
