package main

import (
	"context"
	"encoding/json"
	"fmt"
	"html"
	"net/http"
	"os"
	"strconv"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/golang-jwt/jwt/v4"
	"golang.org/x/crypto/bcrypt"
)

// --- Servicios de Autenticación ---

// AuthService maneja la lógica de autenticación.
type AuthService struct {
	jwtSecret       []byte
	accessTokenTTL  time.Duration
	refreshTokenTTL time.Duration
}

// NewAuthService crea un nuevo servicio de autenticación.
func NewAuthService(jwtSecret string) *AuthService {
	return &AuthService{
		jwtSecret:       []byte(jwtSecret),
		accessTokenTTL:  time.Hour * 1,      // Access token: 1 hora
		refreshTokenTTL: time.Hour * 24 * 7, // Refresh token: 7 días
	}
}

// TokenPair contiene ambos tokens JWT.
type TokenPair struct {
	AccessToken  string `json:"access_token"`
	RefreshToken string `json:"refresh_token"`
	ExpiresIn    int64  `json:"expires_in"` // Segundos hasta que expire el access token
}

// GenerateTokenPair genera un par de tokens (access + refresh).
func (s *AuthService) GenerateTokenPair(userID int) (*TokenPair, error) {
	now := time.Now()

	// Access Token (corta duración)
	accessClaims := jwt.MapClaims{
		"user_id": float64(userID),
		"type":    "access",
		"exp":     now.Add(s.accessTokenTTL).Unix(),
		"iat":     now.Unix(),
	}
	accessToken := jwt.NewWithClaims(jwt.SigningMethodHS256, accessClaims)
	accessTokenString, err := accessToken.SignedString(s.jwtSecret)
	if err != nil {
		return nil, fmt.Errorf("error generating access token: %w", err)
	}

	// Refresh Token (larga duración)
	refreshClaims := jwt.MapClaims{
		"user_id": float64(userID),
		"type":    "refresh",
		"exp":     now.Add(s.refreshTokenTTL).Unix(),
		"iat":     now.Unix(),
	}
	refreshToken := jwt.NewWithClaims(jwt.SigningMethodHS256, refreshClaims)
	refreshTokenString, err := refreshToken.SignedString(s.jwtSecret)
	if err != nil {
		return nil, fmt.Errorf("error generating refresh token: %w", err)
	}

	return &TokenPair{
		AccessToken:  accessTokenString,
		RefreshToken: refreshTokenString,
		ExpiresIn:    int64(s.accessTokenTTL.Seconds()),
	}, nil
}

// GenerateTokenPairWithRole genera un par de tokens que incluyen el rol del usuario.
// Usado por el Identity Broker para emitir tokens con información de rol.
func (s *AuthService) GenerateTokenPairWithRole(userID int, role string) (*TokenPair, error) {
	now := time.Now()

	// Access Token con rol
	accessClaims := jwt.MapClaims{
		"user_id": float64(userID),
		"role":    role,
		"type":    "access",
		"exp":     now.Add(s.accessTokenTTL).Unix(),
		"iat":     now.Unix(),
	}
	accessToken := jwt.NewWithClaims(jwt.SigningMethodHS256, accessClaims)
	accessTokenString, err := accessToken.SignedString(s.jwtSecret)
	if err != nil {
		return nil, fmt.Errorf("error generating access token with role: %w", err)
	}

	// Refresh Token con rol
	refreshClaims := jwt.MapClaims{
		"user_id": float64(userID),
		"role":    role,
		"type":    "refresh",
		"exp":     now.Add(s.refreshTokenTTL).Unix(),
		"iat":     now.Unix(),
	}
	refreshToken := jwt.NewWithClaims(jwt.SigningMethodHS256, refreshClaims)
	refreshTokenString, err := refreshToken.SignedString(s.jwtSecret)
	if err != nil {
		return nil, fmt.Errorf("error generating refresh token with role: %w", err)
	}

	return &TokenPair{
		AccessToken:  accessTokenString,
		RefreshToken: refreshTokenString,
		ExpiresIn:    int64(s.accessTokenTTL.Seconds()),
	}, nil
}

// ValidateToken valida un token y devuelve los claims.
func (s *AuthService) ValidateToken(tokenString string) (jwt.MapClaims, error) {
	token, err := jwt.Parse(tokenString, func(token *jwt.Token) (interface{}, error) {
		if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, fmt.Errorf("unexpected signing method: %v", token.Header["alg"])
		}
		return s.jwtSecret, nil
	})

	if err != nil {
		return nil, err
	}

	if claims, ok := token.Claims.(jwt.MapClaims); ok && token.Valid {
		// Validar explícitamente que el token tiene fecha de expiración
		if _, hasExp := claims["exp"]; !hasExp {
			return nil, fmt.Errorf("token missing expiration claim")
		}
		return claims, nil
	}

	return nil, fmt.Errorf("invalid token")
}

// RefreshTokens genera nuevos tokens a partir de un refresh token válido.
func (s *AuthService) RefreshTokens(refreshToken string) (*TokenPair, error) {
	claims, err := s.ValidateToken(refreshToken)
	if err != nil {
		return nil, err
	}

	// Verificar que sea un refresh token
	tokenType, ok := claims["type"].(string)
	if !ok || tokenType != "refresh" {
		return nil, fmt.Errorf("invalid token type")
	}

	// Type assertion segura para user_id (HAL-006)
	userIDFloat, ok := claims["user_id"].(float64)
	if !ok {
		return nil, fmt.Errorf("invalid user_id claim in token")
	}
	userID := int(userIDFloat)
	return s.GenerateTokenPair(userID)
}

// HashPassword genera un hash bcrypt de la contraseña.
func HashPassword(password string) (string, error) {
	bytes, err := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
	return string(bytes), err
}

// CheckPassword compara una contraseña con su hash.
func CheckPassword(password, hash string) bool {
	err := bcrypt.CompareHashAndPassword([]byte(hash), []byte(password))
	return err == nil
}

// --- Instancia global del servicio de auth ---
var Auth *AuthService

// --- Nuevos Handlers con buenas prácticas ---

// handleLoginV2 maneja el login con email/password de forma segura.
func handleLoginV2(c *gin.Context) {
	var req LoginRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		RespondError(c, ErrValidation("Formato de petición inválido"))
		return
	}

	// Validar entrada
	if apiErr := req.Validate(); apiErr != nil {
		RespondError(c, apiErr)
		return
	}

	// Buscar usuario por email
	user, err := Repos.Users.FindByEmail(c.Request.Context(), req.Email)
	if err != nil {
		Logger.Error("Error buscando usuario", "error", err)
		RespondError(c, ErrInternal())
		return
	}

	if user == nil {
		RespondError(c, ErrInvalidCredentials())
		return
	}

	// Verificar contraseña
	if !CheckPassword(req.Password, user.PasswordHash) {
		RespondError(c, ErrInvalidCredentials())
		return
	}

	// Actualizar último login
	_ = Repos.Users.UpdateLastLogin(c.Request.Context(), user.ID)

	// Generar tokens
	tokens, err := Auth.GenerateTokenPair(user.ID)
	if err != nil {
		Logger.Error("Error generando tokens", "error", err)
		RespondError(c, ErrInternal())
		return
	}

	Logger.Info("Usuario autenticado", "user_id", user.ID, "email", user.Email)
	RespondSuccess(c, tokens)
}

// RegisterRequest representa los datos para registro con email/password.
type RegisterRequest struct {
	Email    string `json:"email" binding:"required,email"`
	Password string `json:"password" binding:"required,min=8"`
	Name     string `json:"name" binding:"required"`
	LastName string `json:"last_name" binding:"required"`
}

// Validate valida RegisterRequest.
func (r *RegisterRequest) Validate() *APIError {
	if strings.TrimSpace(r.Email) == "" {
		return ErrMissingField("email")
	}
	if !strings.Contains(r.Email, "@") {
		return ErrInvalidInput("email", "El email no tiene un formato válido")
	}
	if len(r.Password) < 8 {
		return ErrInvalidInput("password", "La contraseña debe tener al menos 8 caracteres")
	}
	if strings.TrimSpace(r.Name) == "" {
		return ErrMissingField("name")
	}
	if strings.TrimSpace(r.LastName) == "" {
		return ErrMissingField("last_name")
	}
	return nil
}

// handleRegisterV2 maneja el registro con email/password.
func handleRegisterV2(c *gin.Context) {
	var req RegisterRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		RespondError(c, ErrValidation("Formato de petición inválido"))
		return
	}

	if apiErr := req.Validate(); apiErr != nil {
		RespondError(c, apiErr)
		return
	}

	// Verificar si el email ya está registrado
	existing, err := Repos.Users.FindByEmail(c.Request.Context(), req.Email)
	if err != nil {
		Logger.Error("Error buscando usuario", "error", err)
		RespondError(c, ErrInternal())
		return
	}
	if existing != nil {
		RespondError(c, ErrAlreadyExists("El email"))
		return
	}

	// Hash de la contraseña
	hashed, err := HashPassword(req.Password)
	if err != nil {
		Logger.Error("Error hasheando contraseña", "error", err)
		RespondError(c, ErrInternal())
		return
	}

	// Crear usuario
	user := &User{
		Email:        req.Email,
		PasswordHash: hashed,
	}
	userID, err := Repos.Users.Create(c.Request.Context(), user)
	if err != nil {
		Logger.Error("Error creando usuario", "error", err)
		RespondError(c, ErrInternal())
		return
	}

	// Crear perfil
	profile := &Profile{
		UserID:   userID,
		Name:     strings.TrimSpace(req.Name),
		LastName: strings.TrimSpace(req.LastName),
	}
	if err := Repos.Profiles.Create(c.Request.Context(), profile); err != nil {
		Logger.Error("Error creando perfil", "error", err)
		// El usuario ya se creó, continuamos sin perfil
	}

	// Generar tokens
	tokens, err := Auth.GenerateTokenPair(userID)
	if err != nil {
		Logger.Error("Error generando tokens", "error", err)
		RespondError(c, ErrInternal())
		return
	}

	Logger.Info("Usuario registrado", "user_id", userID, "email", req.Email)
	RespondCreated(c, tokens)
}

// handleRefreshToken renueva el par de tokens.
func handleRefreshToken(c *gin.Context) {
	var req struct {
		RefreshToken string `json:"refresh_token" binding:"required"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		RespondError(c, ErrMissingField("refresh_token"))
		return
	}

	tokens, err := Auth.RefreshTokens(req.RefreshToken)
	if err != nil {
		Logger.Warn("Intento de refresh con token inválido", "error", err)
		RespondError(c, ErrInvalidToken())
		return
	}

	RespondSuccess(c, tokens)
}

// handleUploadVideoV2 maneja la subida de video con validación completa.
// Solo profesores, moderadores y administradores pueden subir videos.
func handleUploadVideoV2(c *gin.Context) {
	userID := getUserIDFromContext(c)
	if userID == 0 {
		RespondError(c, ErrUnauthorized())
		return
	}

	// Verificar que el usuario tenga permiso para subir contenido
	var roleCode string
	err := DB.QueryRowContext(c.Request.Context(), `
		SELECT tu.codigo FROM usuarios u
		JOIN tipos_usuario tu ON u.id_tipo_usuario = tu.id_tipo_usuario
		WHERE u.id_usuario = $1`, userID).Scan(&roleCode)
	if err != nil {
		Logger.Error("Error verificando rol", "error", err, "user_id", userID)
		RespondError(c, ErrInternal())
		return
	}
	if roleCode == "estudiante" {
		RespondError(c, ErrForbidden("Solo profesores y administradores pueden subir videos"))
		return
	}

	// Validar campos de texto
	var req VideoUploadRequest
	if err := c.ShouldBind(&req); err != nil {
		RespondError(c, ErrValidation("El título es requerido"))
		return
	}

	if apiErr := req.Validate(); apiErr != nil {
		RespondError(c, apiErr)
		return
	}

	// Obtener y validar archivo
	fileHeader, err := c.FormFile("video")
	if err != nil {
		RespondError(c, ErrMissingField("video"))
		return
	}

	contentType := c.PostForm("content_type")
	if contentType == "" {
		contentType = "video"
	}

	validator := NewFileValidator()
	var apiErr *APIError
	if contentType == "imagen" {
		apiErr = validator.ValidateImage(fileHeader)
	} else {
		apiErr = validator.ValidateVideo(fileHeader)
	}

	if apiErr != nil {
		RespondError(c, apiErr)
		return
	}

	// Abrir archivo para subir
	file, err := fileHeader.Open()
	if err != nil {
		RespondError(c, ErrInternal().WithDetails("No se pudo abrir el archivo"))
		return
	}
	defer file.Close()

	// Subir a Azure
	result, err := Storage.UploadVideo(c.Request.Context(), file, "videos")
	if err != nil {
		Logger.Error("Error subiendo contenido a Azure", "error", err, "user_id", userID)
		RespondError(c, ErrStorage("Error al subir el archivo"))
		return
	}

	thumbnailURL := result.URL // Fallback si no hay miniatura

	// Procesar miniatura opcional (thumbnail)
	if thumbHeader, err := c.FormFile("thumbnail"); err == nil {
		if imgErr := validator.ValidateImage(thumbHeader); imgErr == nil {
			if thumbFile, err := thumbHeader.Open(); err == nil {
				defer thumbFile.Close()
				publicID := fmt.Sprintf("%d_%s", time.Now().UnixNano(), thumbHeader.Filename)
				if thumbResult, err := Storage.UploadImage(c.Request.Context(), thumbFile, "thumbnails", publicID, false); err == nil {
					thumbnailURL = thumbResult.URL
					Logger.Info("Thumbnail personalizado subido", "url", thumbnailURL)
				} else {
					Logger.Warn("Error subiendo thumbnail", "error", err)
				}
			}
		} else {
			Logger.Warn("Thumbnail inválido, usando fallback", "error", imgErr.Message)
		}
	}

	// Guardar en base de datos con estado 'processing' (el Worker lo cambiará a 'ready')
	video := &Video{
		Title:        req.Title,
		Description:  req.Description,
		AuthorID:     userID,
		VideoURL:     result.URL,
		ThumbnailURL: thumbnailURL,
		ContentType:  contentType,
		Status:       "processing",
	}

	videoID, err := Repos.Videos.Create(c.Request.Context(), video)
	if err != nil {
		Logger.Error("Error guardando video en BD", "error", err, "user_id", userID)
		RespondError(c, ErrDatabase("Error al guardar el video"))
		return
	}

	// Invalidar caché del feed (hay un video nuevo)
	if Cache != nil {
		Cache.InvalidateFeed(c.Request.Context())
	}

	Logger.Info("Video subido", "video_id", videoID, "user_id", userID)

	// Encolar tarea de procesamiento HLS en Redis (asíncrono, no bloquea)
	go func() {
		if Cache != nil {
			taskPayload := map[string]interface{}{
				"video_id":   fmt.Sprintf("%d", videoID),
				"source_url": result.URL,
			}
			taskJSON, err := json.Marshal(taskPayload)
			if err != nil {
				Logger.Error("Error serializando tarea HLS", "error", err, "video_id", videoID)
				return
			}
			// Encolar en la cola HLS (nombre configurable por entorno)
			hlsQueueName := os.Getenv("HLS_QUEUE_NAME")
			if hlsQueueName == "" {
				hlsQueueName = "video_processing"
			}
			ctx := context.Background()
			if err := Cache.EnqueueTask(ctx, hlsQueueName, string(taskJSON)); err != nil {
				Logger.Error("Error encolando tarea HLS en Redis", "error", err, "video_id", videoID, "queue", hlsQueueName)
			} else {
				Logger.Info("Tarea HLS encolada exitosamente", "video_id", videoID, "queue", hlsQueueName)
			}
		} else {
			Logger.Warn("Redis no disponible, video quedará sin HLS", "video_id", videoID)
		}
	}()

	RespondCreated(c, gin.H{
		"id":        videoID,
		"video_url": result.URL,
		"status":    "processing",
		"message":   "Video subido. El procesamiento HLS está en curso.",
	})
}

// handleVideoReady recibe la notificación del Video Worker Python
// cuando el procesamiento HLS ha terminado (o ha fallado).
// Endpoint interno protegido con API Key: POST /api/v1/internal/video-ready
func handleVideoReady(c *gin.Context) {
	// Validar API Key interna
	apiKey := c.GetHeader("X-Internal-API-Key")
	expectedKey := os.Getenv("VIDEO_WORKER_API_KEY")
	if expectedKey == "" || apiKey != expectedKey {
		Logger.Warn("Intento de acceso no autorizado a /video-ready", "provided_key", apiKey[:min(len(apiKey), 8)]+"...")
		RespondError(c, ErrUnauthorized())
		return
	}

	var req struct {
		VideoID string `json:"video_id" binding:"required"`
		HlsURL  string `json:"hls_url"`
		Status  string `json:"status" binding:"required"` // ready or failed
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		RespondError(c, ErrValidation("Formato de petición inválido"))
		return
	}

	// Validar que el status sea válido
	if req.Status != "ready" && req.Status != "failed" {
		RespondError(c, ErrInvalidInput("status", "Status debe ser 'ready' o 'failed'"))
		return
	}

	videoID, err := strconv.Atoi(req.VideoID)
	if err != nil {
		RespondError(c, ErrInvalidInput("video_id", "ID de video inválido"))
		return
	}

	// Actualizar el video en la base de datos
	var updateErr error
	if req.Status == "ready" && req.HlsURL != "" {
		_, updateErr = DB.ExecContext(c.Request.Context(),
			`UPDATE contenidos SET hls_url = $1, status = 'ready' WHERE id_contenido = $2`,
			req.HlsURL, videoID)
	} else {
		_, updateErr = DB.ExecContext(c.Request.Context(),
			`UPDATE contenidos SET status = $1 WHERE id_contenido = $2`,
			req.Status, videoID)
	}

	if updateErr != nil {
		Logger.Error("Error actualizando estado del video", "error", updateErr, "video_id", videoID)
		RespondError(c, ErrDatabase("Error al actualizar el video"))
		return
	}

	// Invalidar caché del feed (el video cambió de estado)
	if Cache != nil {
		Cache.InvalidateFeed(c.Request.Context())
	}

	Logger.Info("Video processing callback received", "video_id", videoID, "status", req.Status)
	RespondSuccess(c, gin.H{
		"video_id": videoID,
		"status":   req.Status,
		"message":  "Video status updated successfully",
	})
}

// handleRegisterView registra un evento de reproducción (view) para un video.
// Protegido con debounce: máximo 1 view por usuario/video cada 30 segundos para evitar inflación artificial.
func handleRegisterView(c *gin.Context) {
	userID := getUserIDFromContext(c)
	if userID == 0 {
		RespondError(c, ErrUnauthorized())
		return
	}

	videoID, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		RespondError(c, ErrInvalidInput("id", "ID de video inválido"))
		return
	}

	// Debounce: si Redis está disponible, evitamos vistas duplicadas rápidas
	if Cache != nil {
		cacheKey := fmt.Sprintf("view_debounce:%d:%d", userID, videoID)
		ctx := c.Request.Context()
		// SetNX = "set if not exists", retorna true solo si la clave NO existía
		wasSet, err := Cache.SetNX(ctx, cacheKey, "1", 30*time.Second)
		if err == nil && !wasSet {
			// Ya registramos una vista hace menos de 30s, ignorar silenciosamente
			RespondSuccess(c, gin.H{"status": "debounced"})
			return
		}
	}

	// Responder inmediatamente al cliente (no bloquear)
	RespondSuccess(c, gin.H{"status": "viewed"})

	// Disparar tracking en background (asíncrono, no bloquea respuesta)
	SendTrackingEvent(context.Background(), c.GetHeader("Authorization"), TrackingEvent{
		UserID:    userID,
		ContentID: videoID,
		EventType: "view",
		Metadata:  map[string]any{"source": "flutter_player"},
	})
}

// handleToggleLikeV2 maneja likes usando repositorios.
func handleToggleLikeV2(c *gin.Context) {
	userID := getUserIDFromContext(c)
	if userID == 0 {
		RespondError(c, ErrUnauthorized())
		return
	}

	videoID, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		RespondError(c, ErrInvalidInput("id", "ID de video inválido"))
		return
	}

	// Verificar que el video existe
	exists, err := Repos.Videos.ExistsByID(c.Request.Context(), videoID)
	if err != nil {
		RespondError(c, ErrInternal())
		return
	}
	if !exists {
		RespondError(c, ErrNotFound("Video"))
		return
	}

	isLiked, likesCount, err := Repos.Interactions.ToggleLike(c.Request.Context(), userID, videoID)
	if err != nil {
		Logger.Error("Error toggle like", "error", err, "user_id", userID, "video_id", videoID)
		RespondError(c, ErrDatabase("Error al procesar like"))
		return
	}

	// Invalidar caché del feed (los contadores de likes cambiaron)
	if Cache != nil {
		Cache.InvalidateFeed(c.Request.Context())
	}

	RespondSuccess(c, gin.H{
		"id":       videoID,
		"likes":    likesCount,
		"is_liked": isLiked,
	})

	// --- Integración Tracking Service ---
	eventType := "like"
	if !isLiked {
		eventType = "unlike"
	}
	SendTrackingEvent(context.Background(), c.GetHeader("Authorization"), TrackingEvent{
		UserID:    userID,
		ContentID: videoID,
		EventType: eventType,
	})

	// --- Generar notificación al dueño del video ---
	if isLiked {
		go func() {
			ctx := context.Background()
			video, err := Repos.Videos.FindByID(ctx, videoID)
			if err != nil || video == nil || video.AuthorID == userID {
				return // No notificar errores ni self-likes
			}
			actor, _ := Repos.Users.FindByID(ctx, userID)
			actorName := "Alguien"
			if actor != nil {
				actorName = actor.Username
			}
			CreateNotificationAsync(video.AuthorID, "like",
				"Nuevo like",
				" le dio like a tu video \""+video.Title+"\"",
				actorName, videoID)
		}()
	}
}

// handleToggleBookmarkV2 maneja bookmarks usando repositorios.
func handleToggleBookmarkV2(c *gin.Context) {
	userID := getUserIDFromContext(c)
	if userID == 0 {
		RespondError(c, ErrUnauthorized())
		return
	}

	videoID, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		RespondError(c, ErrInvalidInput("id", "ID de video inválido"))
		return
	}

	isBookmarked, err := Repos.Bookmarks.Toggle(c.Request.Context(), userID, videoID)
	if err != nil {
		Logger.Error("Error toggle bookmark", "error", err, "user_id", userID, "video_id", videoID)
		RespondError(c, ErrDatabase("Error al guardar"))
		return
	}

	RespondSuccess(c, gin.H{
		"id":            videoID,
		"is_bookmarked": isBookmarked,
	})

	// --- Integración Tracking Service ---
	eventType := "bookmark"
	if !isBookmarked {
		eventType = "unbookmark"
	}
	SendTrackingEvent(context.Background(), c.GetHeader("Authorization"), TrackingEvent{
		UserID:    userID,
		ContentID: videoID,
		EventType: eventType,
	})
}

// handleGetBookmarksV2 obtiene la lista de bookmarks del usuario.
// Soporta paginacion local (limit, offset).
func handleGetBookmarksV2(c *gin.Context) {
	userID := getUserIDFromContext(c)
	if userID == 0 {
		RespondError(c, ErrUnauthorized())
		return
	}

	limit := 20
	if limitStr := c.Query("limit"); limitStr != "" {
		if l, err := strconv.Atoi(limitStr); err == nil && l > 0 {
			limit = l
		}
	}

	offset := 0
	if offsetStr := c.Query("offset"); offsetStr != "" {
		if o, err := strconv.Atoi(offsetStr); err == nil && o >= 0 {
			offset = o
		}
	}

	videos, err := Repos.Bookmarks.GetUserBookmarks(c.Request.Context(), userID, limit, offset)
	if err != nil {
		Logger.Error("Error get bookmarks", "error", err, "user_id", userID)
		RespondError(c, ErrDatabase("Error al obtener guardados"))
		return
	}

	RespondSuccess(c, videos)
}

// handleGetCommentsV2 obtiene comentarios usando repositorios.
// Usa caché Redis si está disponible (TTL: 1 min).
func handleGetCommentsV2(c *gin.Context) {
	videoID, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		RespondError(c, ErrInvalidInput("id", "ID de video inválido"))
		return
	}

	// Intentar obtener del caché
	if Cache != nil {
		if cached, found := Cache.GetComments(c.Request.Context(), videoID); found {
			RespondSuccess(c, cached)
			return
		}
	}

	comments, err := Repos.Comments.GetByVideoID(c.Request.Context(), videoID, 50)
	if err != nil {
		Logger.Error("Error obteniendo comentarios", "error", err, "video_id", videoID)
		RespondError(c, ErrDatabase("Error al cargar comentarios"))
		return
	}

	if comments == nil {
		comments = []Comment{}
	}

	// Convertir a formato de respuesta
	var response []gin.H
	for _, c := range comments {
		response = append(response, gin.H{
			"id":         c.ID,
			"user_id":    c.UserID,
			"username":   c.Username,
			"avatar_url": c.AvatarURL,
			"text":       c.Text,
			"created_at": c.CreatedAt.Format(time.RFC3339),
		})
	}

	if response == nil {
		response = []gin.H{}
	}

	// Guardar en caché
	if Cache != nil {
		Cache.SetComments(c.Request.Context(), videoID, response)
	}

	RespondSuccess(c, response)
}

// handleDeleteCommentV2 permite a un usuario borrar su propio comentario.
func handleDeleteCommentV2(c *gin.Context) {
	userIDVal, exists := c.Get("id_usuario")
	if !exists {
		Logger.Warn("Usuario no autenticado intentando borrar comentario")
		c.JSON(http.StatusUnauthorized, gin.H{"error": "No autorizado"})
		return
	}
	userID := int(userIDVal.(float64))

	commentID, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		Logger.Warn("ID de comentario inválido en delete", "id", c.Param("id"))
		c.JSON(http.StatusBadRequest, gin.H{"error": "ID de comentario inválido"})
		return
	}

	ctx := context.Background()
	err = Repos.Comments.Delete(ctx, commentID, userID)
	if err != nil {
		Logger.Error("Error borrando comentario", "error", err, "comment_id", commentID)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Error al borrar el comentario o no tienes permiso"})
		return
	}

	// Invalidar caché (de forma simple)
	videoID, _ := strconv.Atoi(c.Query("video_id")) // Opcional, para limpiar caché si se pasa
	if videoID > 0 {
		cacheKey := fmt.Sprintf("comments:video:%d", videoID)
		Cache.Delete(ctx, cacheKey)
	}

	Logger.Info("Comentario borrado exitosamente", "comment_id", commentID, "user_id", userID)
	c.JSON(http.StatusOK, gin.H{
		"status":  "success",
		"message": "Comentario eliminado",
	})
}

// handleReportCommentV2 permite a un usuario reportar un comentario inapropiado.
func handleReportCommentV2(c *gin.Context) {
	userID := getUserIDFromContext(c)
	if userID == 0 {
		Logger.Warn("Usuario no autenticado intentando reportar comentario")
		c.JSON(http.StatusUnauthorized, gin.H{"error": "No autorizado"})
		return
	}

	commentID, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "ID de comentario inválido"})
		return
	}

	var req struct {
		Motivo string `json:"motivo" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Falta el motivo del reporte"})
		return
	}

	ctx := context.Background()
	err = Repos.Comments.Report(ctx, commentID, userID, req.Motivo)
	if err != nil {
		Logger.Error("Error guardando reporte de comentario", "error", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "No se pudo enviar el reporte"})
		return
	}

	Logger.Info("Comentario reportado", "comment_id", commentID, "user_id", userID, "motivo", req.Motivo)
	c.JSON(http.StatusOK, gin.H{
		"status":  "success",
		"message": "Reporte enviado exitosamente. Gracias por ayudar a mantener la comunidad segura.",
	})
}

// handleCreateCommentV2 crea comentario con validación.
func handleCreateCommentV2(c *gin.Context) {
	userID := getUserIDFromContext(c)
	if userID == 0 {
		RespondError(c, ErrUnauthorized())
		return
	}

	videoID, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		RespondError(c, ErrInvalidInput("id", "ID de video inválido"))
		return
	}

	var req CommentRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		RespondError(c, ErrMissingField("text"))
		return
	}

	if apiErr := req.Validate(); apiErr != nil {
		RespondError(c, apiErr)
		return
	}

	comment := &Comment{
		UserID:  userID,
		VideoID: videoID,
		Text:    html.EscapeString(strings.TrimSpace(req.Text)),
	}

	commentID, err := Repos.Comments.Create(c.Request.Context(), comment)
	if err != nil {
		Logger.Error("Error creando comentario", "error", err, "user_id", userID, "video_id", videoID)
		RespondError(c, ErrDatabase("Error al guardar el comentario"))
		return
	}

	// Invalidar caché de comentarios del video
	if Cache != nil {
		Cache.InvalidateComments(c.Request.Context(), videoID)
	}

	// --- Integración Tracking Service ---
	SendTrackingEvent(context.Background(), c.GetHeader("Authorization"), TrackingEvent{
		UserID:    userID,
		ContentID: videoID,
		EventType: "comment",
	})

	// --- Generar notificación al dueño del video ---
	go func() {
		ctx := context.Background()
		video, err := Repos.Videos.FindByID(ctx, videoID)
		if err != nil || video == nil || video.AuthorID == userID {
			return // No notificar errores ni auto-comentarios
		}
		actor, _ := Repos.Users.FindByID(ctx, userID)
		actorName := "Alguien"
		if actor != nil {
			actorName = actor.Username
		}
		CreateNotificationAsync(video.AuthorID, "comment",
			"Nuevo comentario",
			" comentó en tu video \""+video.Title+"\"",
			actorName, videoID)
	}()

	Logger.Info("Comentario creado", "comment_id", commentID, "user_id", userID, "video_id", videoID)
	RespondCreated(c, gin.H{
		"id":      commentID,
		"message": "Comentario creado exitosamente",
	})
}

// handleGetFeedV2 obtiene el feed usando repositorios.
// Usa caché Redis si está disponible (TTL: 5 min).
func handleGetFeedV2(c *gin.Context) {
	page, _ := strconv.Atoi(c.DefaultQuery("page", "1"))
	if page < 1 {
		page = 1
	}
	// Límite de página para evitar offsets astronómicos
	if page > 1000 {
		page = 1000
	}

	// Intentar obtener del caché
	if Cache != nil {
		if cached, found := Cache.GetFeed(c.Request.Context(), page); found {
			Logger.Info("Feed servido desde caché", "page", page)
			RespondSuccess(c, cached)
			return
		}
	}

	limit := 10
	offset := (page - 1) * limit

	// Obtener userID si está autenticado (opcional)
	var userID *int
	if id := getUserIDFromContext(c); id != 0 {
		userID = &id
	}

	videos, err := Repos.Videos.GetFeed(c.Request.Context(), limit, offset, userID)
	if err != nil {
		Logger.Error("Error obteniendo feed", "error", err)
		RespondError(c, ErrDatabase("Error al cargar videos"))
		return
	}

	// Convertir a formato de respuesta
	var response []gin.H
	for _, v := range videos {
		response = append(response, gin.H{
			"id":            strconv.Itoa(v.ID),
			"title":         v.Title,
			"description":   v.Description,
			"author_name":   v.AuthorName,
			"video_url":     v.VideoURL,
			"thumbnail_url": v.ThumbnailURL,
			"content_type":  v.ContentType,
			"created_at":    v.CreatedAt.Format(time.RFC3339),
			"likes":         v.Likes,
			"comments":      v.Comments,
			"is_liked":      v.IsLiked,
			"is_bookmarked": v.IsBookmarked,
			"category":      v.Category,
		})
	}

	if response == nil {
		response = []gin.H{}
	}

	result := gin.H{"videos": response}

	// Guardar en caché (solo feeds públicos sin userID para evitar datos cruzados)
	if Cache != nil && userID == nil {
		Cache.SetFeed(c.Request.Context(), page, result)
	}

	// --- Integración Tracking Service ---
	// Emitir evento 'view' por cada video cargado en el feed (solo si autenticado)
	if userID != nil {
		for _, v := range videos {
			SendTrackingEvent(context.Background(), c.GetHeader("Authorization"), TrackingEvent{
				UserID:    *userID,
				ContentID: v.ID,
				EventType: "view",
			})
		}
	}

	RespondSuccess(c, result)
}

// handleSearchV2 busca videos usando repositorios.
// Usa caché Redis si está disponible (TTL: 2 min).
func handleSearchV2(c *gin.Context) {
	query := c.Query("q")
	dateFilter := c.Query("date")
	authorFilter := c.Query("author")
	categoryFilter := c.Query("category")

	if query == "" {
		RespondError(c, ErrMissingField("q"))
		return
	}

	if len(query) > 100 {
		RespondError(c, ErrInvalidInput("q", "La búsqueda es demasiado larga (máx 100 caracteres)"))
		return
	}

	cacheKeyParams := fmt.Sprintf("%s|%s|%s|%s", query, dateFilter, authorFilter, categoryFilter)

	// Intentar obtener del caché
	if Cache != nil {
		if cached, found := Cache.GetSearch(c.Request.Context(), cacheKeyParams); found {
			RespondSuccess(c, cached)
			return
		}
	}

	// Obtener userID si está autenticado (opcional)
	var userID *int
	if id := getUserIDFromContext(c); id != 0 {
		userID = &id
	}

	videos, err := Repos.Videos.Search(c.Request.Context(), query, dateFilter, authorFilter, categoryFilter, 20, userID)
	if err != nil {
		Logger.Error("Error en búsqueda", "error", err, "query", query)
		RespondError(c, ErrDatabase("Error al buscar videos"))
		return
	}

	var response []gin.H
	for _, v := range videos {
		response = append(response, gin.H{
			"id":            strconv.Itoa(v.ID),
			"title":         v.Title,
			"description":   v.Description,
			"author_name":   v.AuthorName,
			"video_url":     v.VideoURL,
			"thumbnail_url": v.ThumbnailURL,
			"content_type":  v.ContentType,
			"created_at":    v.CreatedAt.Format(time.RFC3339),
			"likes":         v.Likes,
			"is_liked":      v.IsLiked,
			"is_bookmarked": v.IsBookmarked,
			"category":      v.Category,
		})
	}

	if response == nil {
		response = []gin.H{}
	}

	result := gin.H{"videos": response}

	// Guardar en caché
	if Cache != nil {
		Cache.SetSearch(c.Request.Context(), cacheKeyParams, result)
	}

	// --- Integración Tracking Service ---
	uid := getUserIDFromContext(c)
	if uid > 0 {
		SendTrackingEvent(context.Background(), c.GetHeader("Authorization"), TrackingEvent{
			UserID:    uid,
			ContentID: 0,
			EventType: "search",
			Metadata:  map[string]any{"query": query, "date": dateFilter, "author": authorFilter, "category": categoryFilter},
		})
	}

	Logger.Info("Búsqueda realizada", "query", query, "results", len(response))
	RespondSuccess(c, result)
}

// --- Helper ---

// getUserIDFromContext extrae el userID del contexto de Gin.
func getUserIDFromContext(c *gin.Context) int {
	userIDVal, exists := c.Get("userID")
	if !exists {
		return 0
	}
	return int(userIDVal.(float64))
}

// UpdateInterestsRequest define el payload para actualizar los intereses del usuario.
type UpdateInterestsRequest struct {
	Interests []string `json:"interests" binding:"required"`
}

// handleUpdateInterestsV2 guarda los intereses del usuario en la columna "intereses" de la tabla perfiles.
func handleUpdateInterestsV2(c *gin.Context) {
	var req UpdateInterestsRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		RespondError(c, ErrInvalidInput("payload", "El formato JSON es inválido o falta el campo 'interests'"))
		return
	}

	userID := getUserIDFromContext(c)
	if userID == 0 {
		RespondError(c, ErrUnauthorized().WithDetails("Usuario no autenticado"))
		return
	}

	// Evitar arreglos nulos en BD
	if req.Interests == nil {
		req.Interests = []string{}
	}

	// Formatear el slice de strings de Go a literal de arreglo de PostgreSQL: {"a", "b"}
	// pgx soporta pq.Array pero como usamos pgxpool y raw SQL, la forma más limpia
	// es construir el literal string "{math, logic}" para TEXT[]
	arrayLiteral := "{" + strings.Join(req.Interests, ",") + "}"

	query := `UPDATE perfiles SET intereses = $1 WHERE id_usuario = $2`
	_, err := DB.ExecContext(c.Request.Context(), query, arrayLiteral, userID)

	if err != nil {
		Logger.Error("No se pudieron actualizar los intereses", "error", err, "user_id", userID)
		RespondError(c, ErrDatabase("Error al guardar los intereses en la base de datos"))
		return
	}

	Logger.Info("Intereses actualizados exitosamente", "user_id", userID, "intereses", req.Interests)
	RespondSuccess(c, gin.H{"message": "Intereses actualizados correctamente", "interests": req.Interests})
}

// handleGetTrends devuelve los hashtags más populares extraídos de las descripciones de los videos.
func handleGetTrends(c *gin.Context) {
	limit := 6 // Por defecto, Top 6 tendencias
	trends, err := Repos.Videos.GetTrends(c.Request.Context(), limit)
	if err != nil {
		Logger.Error("Error al obtener trends", "error", err)
		RespondError(c, ErrDatabase("Error al obtener tendencias"))
		return
	}
	
	// Asegurar que nunca retorne null
	if trends == nil {
		trends = []TrendingTag{}
	}
	
	RespondSuccess(c, gin.H{"trends": trends})
}

// handleTriggerRetrain contacta el microservicio de Python para entrenar el modelo ML.
// Solo accesible por administradores.
func handleTriggerRetrain(c *gin.Context) {
	// Verificar que el usuario tenga rol
	userID, exists := c.Get("userID")
	if !exists {
		RespondError(c, ErrUnauthorized())
		return
	}

	recomURL := os.Getenv("RECOMMENDATIONS_SERVICE_URL")
	if recomURL == "" {
		recomURL = "http://recommendations:8090"
	}
	recomAPIKey := os.Getenv("RECOMMENDATIONS_API_KEY")

	req, err := http.NewRequest("POST", recomURL+"/api/v1/internal/retrain", nil)
	if err != nil {
		RespondError(c, ErrInternal().WithDetails("Error interno creando petición"))
		return
	}
	req.Header.Set("Authorization", "Bearer "+recomAPIKey)
	req.Header.Set("x-api-key", recomAPIKey)

	client := &http.Client{Timeout: 5 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		Logger.Error("Error contactando microservicio IA", "error", err)
		RespondError(c, ErrInternal().WithDetails("El servidor de inteligencia artificial está inalcanzable"))
		return
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 400 {
	    RespondError(c, NewAPIError(ErrCodeInternal, "El motor IA rechazó la orden de entrenamiento", resp.StatusCode))
		return
	}

	RespondSuccess(c, gin.H{"message": "Entrenamiento neuronal en progreso", "actor_id": userID})
}
