package main

import (
	"context"
	"fmt"
	"html"
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

	// NOTA: Gorse ha sido retirado. El nuevo sistema ML no requiere registrar usuarios de antemano.
	// El Tracking Service se encarga de recolectar los eventos interactuando con Postgres.
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

	validator := NewFileValidator()
	if apiErr := validator.ValidateVideo(fileHeader); apiErr != nil {
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
		Logger.Error("Error subiendo video a Azure", "error", err, "user_id", userID)
		RespondError(c, ErrStorage("Error al subir el video"))
		return
	}

	// Guardar en base de datos
	video := &Video{
		Title:        req.Title,
		Description:  req.Description,
		AuthorID:     userID,
		VideoURL:     result.URL,
		ThumbnailURL: result.URL, // Por ahora usar la misma URL
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
	RespondCreated(c, gin.H{
		"id":        videoID,
		"video_url": result.URL,
		"message":   "Video subido correctamente",
	})

	// NOTA: Gorse ha sido retirado. El nuevo sistema ML no requiere registrar items manualmente,
	// pues lee directamente las features de contenido (y metadata) de la propia base de datos Postgres.
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
		ContentID: videoID,
		EventType: eventType,
	})
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
		ContentID: videoID,
		EventType: eventType,
	})
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
			"video_url":     v.VideoURL,
			"thumbnail_url": v.ThumbnailURL,
			"likes":         v.Likes,
			"comments":      0,
			"is_liked":      false,
			"is_bookmarked": false,
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

	RespondSuccess(c, result)
}

// handleSearchV2 busca videos usando repositorios.
// Usa caché Redis si está disponible (TTL: 2 min).
func handleSearchV2(c *gin.Context) {
	query := c.Query("q")
	if query == "" {
		RespondError(c, ErrMissingField("q"))
		return
	}

	if len(query) > 100 {
		RespondError(c, ErrInvalidInput("q", "La búsqueda es demasiado larga (máx 100 caracteres)"))
		return
	}

	// Intentar obtener del caché
	if Cache != nil {
		if cached, found := Cache.GetSearch(c.Request.Context(), query); found {
			RespondSuccess(c, cached)
			return
		}
	}

	videos, err := Repos.Videos.Search(c.Request.Context(), query, 20)
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
			"video_url":     v.VideoURL,
			"thumbnail_url": v.ThumbnailURL,
			"likes":         v.Likes,
		})
	}

	if response == nil {
		response = []gin.H{}
	}

	result := gin.H{"videos": response}

	// Guardar en caché
	if Cache != nil {
		Cache.SetSearch(c.Request.Context(), query, result)
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
