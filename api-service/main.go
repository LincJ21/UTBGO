package main

import (
	"context"
	"fmt"
	"net/http"
	"os"
	"os/signal"
	"strings"
	"syscall"
	"time"

	"github.com/gin-contrib/cors"
	"github.com/gin-gonic/gin"
	"github.com/golang-jwt/jwt/v4"
	"github.com/joho/godotenv"
)

// Variables de configuración (se cargarán desde .env)
var JWT_SECRET_KEY string

// Global variables to store IDs from reference tables, initialized in main.
var videoContentTypeID int
var publishedContentStateID int
var likeInteractionTypeID int
var bookmarkInteractionTypeID int
var activeCommentStateID int

// Gorse es el cliente global para el motor de recomendaciones.
// Gorse es el cliente global para el motor de recomendaciones.
// var Gorse *GorseClientWrapper

// MLRecommend es el cliente global para el nuevo sistema ML de recomendaciones
var MLRecommend *CustomRecommendationClient

// GlobalRoleMapper es el mapeador de roles global, usado en autenticación
var GlobalRoleMapper *RoleMapper

// --- Middleware de Autenticación ---

func AuthMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		authHeader := c.GetHeader("Authorization")
		if authHeader == "" || !strings.HasPrefix(authHeader, "Bearer ") {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Authorization header required"})
			c.Abort()
			return
		}

		tokenString := strings.TrimPrefix(authHeader, "Bearer ")
		if tokenString == "" {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Token not provided"})
			c.Abort()
			return
		}

		token, err := jwt.Parse(tokenString, func(token *jwt.Token) (interface{}, error) {
			if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
				return nil, fmt.Errorf("unexpected signing method: %v", token.Header["alg"])
			}
			// Usar la variable global en vez de os.Getenv para consistencia con AuthService
			return []byte(JWT_SECRET_KEY), nil
		})

		if err != nil || !token.Valid {
			Logger.Warn("Token JWT inválido", "error", err)
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid token"})
			c.Abort()
			return
		}

		if claims, ok := token.Claims.(jwt.MapClaims); ok {
			userID, ok := claims["user_id"].(float64)
			if !ok {
				c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid token claims"})
				c.Abort()
				return
			}
			Logger.Debug("Token válido", "user_id", int(userID))
			c.Set("userID", userID)
			c.Next()
		} else {
			Logger.Warn("Claims de token inválidos")
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid token claims"})
			c.Abort()
		}
	}
}

// initIdentityBroker inicializa el Identity Broker con los proveedores OIDC
// disponibles según las variables de entorno configuradas.
// Si un proveedor no tiene credenciales, se omite sin error (degradación graciosa).
func initIdentityBroker() {
	ctx := context.Background()
	GlobalRoleMapper = NewRoleMapper() // Usar la versión sin argumentos y asignar al global
	var providers []OIDCProvider

	// --- Proveedor Google OIDC ---
	googleProvider, err := NewGoogleOIDCProvider(ctx)
	if err != nil {
		Logger.Warn("Identity Broker: Google OIDC no disponible", "error", err)
	} else {
		providers = append(providers, googleProvider)
	}

	// --- Proveedor Microsoft Entra ID ---
	msProvider, err := NewMicrosoftOIDCProvider(ctx)
	if err != nil {
		Logger.Warn("Identity Broker: Microsoft Entra ID no disponible", "error", err)
	} else {
		providers = append(providers, msProvider)
	}

	// --- Proveedor Firebase Auth ---
	firebaseProvider, err := NewFirebaseOIDCProvider(ctx)
	if err != nil {
		Logger.Warn("Identity Broker: Firebase Auth no disponible", "error", err)
	} else {
		providers = append(providers, firebaseProvider)
	}

	// --- Ensegurar que el rol 'aspirante' existe en la BD ---
	ensureAspiranteRole(ctx)

	// --- Crear el Identity Broker ---
	if len(providers) > 0 {
		Broker = NewIdentityBroker(Auth, GlobalRoleMapper, providers...)
		Logger.Info("Identity Broker inicializado",
			"providers", len(providers),
		)
	} else {
		Logger.Warn("Identity Broker: ningún proveedor OIDC configurado. El broker está deshabilitado.")
	}
}

// ensureAspiranteRole garantiza que el rol 'aspirante' exista en la tabla tipos_usuario.
// Este rol es necesario para el Identity Broker cuando usuarios externos se registran.
func ensureAspiranteRole(ctx context.Context) {
	var exists bool
	err := DB.QueryRowContext(ctx, "SELECT EXISTS(SELECT 1 FROM tipos_usuario WHERE codigo = 'aspirante')").Scan(&exists)
	if err != nil {
		Logger.Warn("Error verificando rol 'aspirante'", "error", err)
		return
	}
	if !exists {
		_, err = DB.ExecContext(ctx,
			"INSERT INTO tipos_usuario (codigo, nombre, descripcion, nivel_acceso) VALUES ('aspirante', 'Aspirante', 'Usuario externo aspirante', 1)")
		if err != nil {
			Logger.Warn("Error creando rol 'aspirante'", "error", err)
		} else {
			Logger.Info("Rol 'aspirante' creado en la base de datos")
		}
	}
}

func main() {
	// --- Inicialización del Logger ---
	InitLogger()

	// Cargar variables de entorno desde el archivo .env
	// En producción (Render, Railway, etc.) las variables vienen del sistema,
	// así que no importa si .env no existe.
	_ = godotenv.Load("../../.env") // Desarrollo: ruta relativa del proyecto Flutter
	_ = godotenv.Load(".env")       // Producción/Docker: .env en el mismo directorio
	// Si ninguno existe, usa variables de entorno del sistema (lo normal en la nube)

	// HAL-005: Advertencia de seguridad si se ejecuta en modo debug
	if gin.Mode() != gin.ReleaseMode {
		Logger.Warn("⚠️  EJECUTANDO EN MODO DEBUG — NO USAR EN PRODUCCIÓN",
			"gin_mode", gin.Mode())
	}

	// --- Inicialización de la Base de Datos ---
	InitDB(os.Getenv("DB_CONNECTION_STRING"))
	defer DB.Close()

	// --- Inicialización de Repositorios ---
	Repos = NewRepositories()
	Logger.Info("Repositorios inicializados")

	// --- Inicialización de Roles de Administración ---
	// Garantiza que los roles admin/moderador y estados de moderación existan en la BD.
	if err := Repos.Admin.EnsureAdminRole(context.Background()); err != nil {
		Logger.Warn("Error inicializando roles de admin (la BD podría no tener las tablas)", "error", err)
	} else {
		Logger.Info("Roles de administración verificados/creados")
	}

	// --- Inicialización del Proveedor de Almacenamiento ---
	// Se selecciona automáticamente según la variable STORAGE_PROVIDER en .env.
	// Valores soportados: "azure" (por defecto), "cloudinary".
	storageProvider := os.Getenv("STORAGE_PROVIDER")
	switch strings.ToLower(storageProvider) {
	case "cloudinary":
		cloudinaryStorage, err := NewCloudinaryStorage()
		if err != nil {
			Logger.Error("Fallo al inicializar Cloudinary", "error", err)
			os.Exit(1)
		}
		Storage = cloudinaryStorage
		Logger.Info("Proveedor de almacenamiento: Cloudinary")
	default:
		azureStorage, err := NewAzureStorage()
		if err != nil {
			Logger.Error("Fallo al inicializar Azure Blob Storage", "error", err)
			os.Exit(1)
		}
		Storage = azureStorage
		Logger.Info("Proveedor de almacenamiento: Azure Blob Storage")
	}

	// --- Cargar IDs de referencia de la Base de Datos ---
	// Esto asegura que los handlers usen los IDs correctos de las tablas de referencia.
	var err error
	err = DB.QueryRow("SELECT id_tipo_contenido FROM tipos_contenido WHERE codigo = $1", "video").Scan(&videoContentTypeID)
	if err != nil {
		Logger.Warn("Error al obtener id_tipo_contenido para 'video'", "error", err)
	}
	Logger.Info("ID de tipo de contenido cargado", "tipo", "video", "id", videoContentTypeID)

	err = DB.QueryRow("SELECT id_estado_contenido FROM estados_contenido WHERE codigo = $1", "publicado").Scan(&publishedContentStateID)
	if err != nil {
		Logger.Warn("Error al obtener id_estado_contenido para 'publicado'", "error", err)
	}
	Logger.Info("ID de estado de contenido cargado", "tipo", "publicado", "id", publishedContentStateID)

	err = DB.QueryRow("SELECT id_tipo_interaccion FROM tipos_interaccion WHERE codigo = $1", "like").Scan(&likeInteractionTypeID)
	if err != nil {
		Logger.Warn("Error al obtener id_tipo_interaccion para 'like'", "error", err)
	}
	Logger.Info("ID de tipo de interacción cargado", "tipo", "like", "id", likeInteractionTypeID)

	err = DB.QueryRow("SELECT id_tipo_interaccion FROM tipos_interaccion WHERE codigo = $1", "bookmark").Scan(&bookmarkInteractionTypeID)
	if err != nil {
		err = DB.QueryRow("INSERT INTO tipos_interaccion (codigo, nombre, descripcion, incrementa_contador) VALUES ('bookmark', 'Bookmark', 'Guardar para ver después', false) RETURNING id_tipo_interaccion").Scan(&bookmarkInteractionTypeID)
		if err != nil {
			Logger.Warn("Error al crear tipo interacción 'bookmark'", "error", err)
		}
	}
	Logger.Info("ID de tipo de interacción cargado", "tipo", "bookmark", "id", bookmarkInteractionTypeID)

	err = DB.QueryRow("SELECT id_estado_general FROM estados_general WHERE codigo = $1 AND tipo_entidad = 'comentario'", "activo").Scan(&activeCommentStateID)
	if err != nil {
		err = DB.QueryRow("INSERT INTO estados_general (codigo, nombre, descripcion, tipo_entidad) VALUES ('activo', 'Activo', 'Comentario visible', 'comentario') RETURNING id_estado_general").Scan(&activeCommentStateID)
		if err != nil {
			Logger.Warn("Error al crear estado 'activo' para comentarios", "error", err)
		}
	}
	Logger.Info("ID de estado de comentario cargado", "tipo", "activo", "id", activeCommentStateID)

	JWT_SECRET_KEY = os.Getenv("JWT_SECRET_KEY")

	// --- Inicialización del Servicio de Autenticación ---
	Auth = NewAuthService(JWT_SECRET_KEY)
	Logger.Info("Servicio de autenticación inicializado")

	// --- Inicialización del Identity Broker (OIDC) ---
	// Registra los proveedores OIDC disponibles según las variables de entorno.
	// Si un proveedor no tiene credenciales configuradas, se omite (degradación graciosa).
	initIdentityBroker()

	// --- Inicialización de Redis (caché + rate limiting distribuido) ---
	// Si REDIS_URL no está configurada, funciona sin caché (degradación graciosa).
	cacheService, cacheErr := NewCacheService()
	if cacheErr != nil {
		Logger.Warn("Redis no disponible, funcionando sin caché", "error", cacheErr)
	} else {
		Cache = cacheService
		defer Cache.Close()
		Logger.Info("Redis inicializado (caché + rate limiting distribuido)")
	}

	// --- Inicialización de Gorse (Recomendaciones) ---
	// Gorse = NewGorseClient(os.Getenv("GORSE_SERVER_URL"), os.Getenv("GORSE_API_KEY"))
	// if Gorse != nil {
	// 	Logger.Info("Cliente Gorse inicializado")
	// }

	// --- Inicialización de Custom Python Recomendaciones ---
	MLRecommend = NewCustomRecommendationClient(os.Getenv("RECOMMENDATIONS_SERVICE_URL"), os.Getenv("RECOMMENDATIONS_API_KEY"))
	if MLRecommend != nil {
		Logger.Info("Cliente ML Recommendations inicializado")
	}

	router := gin.Default()

	// --- Middlewares de Seguridad ---
	router.Use(SecurityHeadersMiddleware())
	router.Use(RequestLoggerMiddleware())

	// Rate Limiting: 100 requests por minuto por IP
	// Si Redis está disponible, usa rate limiter distribuido (funciona multi-instancia).
	// Si no, usa el rate limiter in-memory (solo single-instance).
	if Cache != nil {
		redisRL := NewRedisRateLimiter(cacheService.client, 100, time.Minute)
		router.Use(RedisRateLimitMiddleware(redisRL))
		Logger.Info("Rate limiter: Redis (distribuido)")
	} else {
		rateLimiter := NewRateLimiter(100, time.Minute)
		router.Use(RateLimitMiddleware(rateLimiter))
		Logger.Info("Rate limiter: in-memory (solo single-instance)")
	}

	// --- AUMENTAR LÍMITE DE SUBIDA DE ARCHIVOS ---
	// Por defecto, Gin tiene un límite bajo (ej. 32MB). Lo aumentamos para permitir videos grandes.
	// 500 << 20 es una forma de calcular 500 MB (500 * 2^20 bytes).
	router.MaxMultipartMemory = 500 << 20 // 500 MB

	// --- Health Check Endpoint ---
	router.GET("/health", func(c *gin.Context) {
		// Verificar conexión a BD
		ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
		defer cancel()
		if err := DB.PingContext(ctx); err != nil {
			c.JSON(http.StatusServiceUnavailable, gin.H{"status": "unhealthy", "db": "disconnected"})
			return
		}
		c.JSON(http.StatusOK, gin.H{"status": "healthy", "db": "connected"})
	})

	// --- Configuración de CORS ---
	// En producción, configura AllowOrigins con dominios específicos.
	allowedOrigins := os.Getenv("ALLOWED_ORIGINS")
	if allowedOrigins == "" {
		if gin.Mode() == gin.ReleaseMode {
			// HAL-002: En producción, NO permitir wildcard. Forzar configuración explícita.
			Logger.Error("ALLOWED_ORIGINS no configurada en modo producción. " +
				"Debes especificar los orígenes permitidos (ej: https://app.utbgo.com)")
			os.Exit(1)
		}
		allowedOrigins = "*" // Solo para desarrollo
	}

	// No combinar AllowCredentials:true con AllowOrigins:["*"] (inseguro y rechazado por navegadores)
	allowCredentials := allowedOrigins != "*"

	router.Use(cors.New(cors.Config{
		AllowOrigins:     strings.Split(allowedOrigins, ","),
		AllowMethods:     []string{"GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"},
		AllowHeaders:     []string{"Origin", "Content-Type", "Authorization"},
		ExposeHeaders:    []string{"Content-Length"},
		AllowCredentials: allowCredentials,
		MaxAge:           12 * time.Hour,
	}))

	// Rutas de Autenticación
	authRoutes := router.Group("/auth/google")
	{
		authRoutes.POST("/verify-token", handleVerifyToken) // Nueva ruta para el flujo nativo
	}

	// Rutas de la API (algunas protegidas)
	api := router.Group("/api")
	{
		videos := api.Group("/videos")
		{
			videos.POST("/:id/like", AuthMiddleware(), handleToggleLike)
			videos.POST("/:id/bookmark", AuthMiddleware(), handleToggleBookmark)
			videos.GET("/:id/comments", handleGetComments)
			videos.POST("/:id/comments", AuthMiddleware(), handleCreateComment) // Nueva ruta
			videos.GET("/feed", handleGetVideosFeed)
			videos.GET("/search", handleSearchVideos)
			videos.POST("/upload", AuthMiddleware(), handleUploadVideo)
		}
		profile := api.Group("/profile")
		{
			profile.GET("/me", AuthMiddleware(), handleGetProfile)
			profile.POST("/avatar", AuthMiddleware(), handleUploadAvatar)
		}
	}

	// --- API v1 (Nuevos handlers con buenas prácticas) ---
	// Mantiene compatibilidad con /api mientras se migra el frontend
	v1 := router.Group("/api/v1")
	{
		// Autenticación — HAL-019: Rate limit más estricto para prevenir fuerza bruta
		auth := v1.Group("/auth")
		authRateLimiter := NewRateLimiter(10, time.Minute) // 10 intentos/min por IP
		auth.Use(RateLimitMiddleware(authRateLimiter))
		{
			auth.POST("/login", handleLoginV2)             // Login email/password
			auth.POST("/register", handleRegisterV2)       // Registro email/password
			auth.POST("/refresh", handleRefreshToken)      // Renovar tokens
			auth.POST("/google/verify", handleVerifyToken) // OAuth Google (legacy)

			// --- Identity Broker OIDC ---
			// Endpoint unificado para autenticación con cualquier proveedor OIDC.
			// POST /api/v1/auth/oidc/:provider  (google, microsoft)
			// GET  /api/v1/auth/oidc/providers  (listar proveedores disponibles)
			oidc := auth.Group("/oidc")
			{
				oidc.POST("/:provider", handleOIDCAuth)     // Autenticación OIDC unificada
				oidc.GET("/providers", handleOIDCProviders) // Listar proveedores
			}
		}

		// Videos
		videos := v1.Group("/videos")
		{
			videos.GET("/feed", handleGetFeedV2)
			videos.GET("/search", handleSearchV2)
			videos.POST("/upload", AuthMiddleware(), handleUploadVideoV2)
			videos.POST("/:id/like", AuthMiddleware(), handleToggleLikeV2)
			videos.POST("/:id/bookmark", AuthMiddleware(), handleToggleBookmarkV2)
			videos.GET("/:id/comments", handleGetCommentsV2)
			videos.POST("/:id/comments", AuthMiddleware(), handleCreateCommentV2)
		}

		// Recomendaciones (Gorse)
		recommend := v1.Group("/recommend")
		{
			// GET /api/v1/recommend/personalized?category=video&n=10
			recommend.GET("/personalized", AuthMiddleware(), handleGetRecommendations)
			// GET /api/v1/recommend/popular?category=video&n=10
			recommend.GET("/popular", handleGetPopularRecommendations)
			// GET /api/v1/recommend/similar/:id?n=10
			recommend.GET("/similar/:id", handleGetSimilarRecommendations)
		}

		// Perfil
		profile := v1.Group("/profile")
		{
			profile.GET("/me", AuthMiddleware(), handleGetProfile)
			profile.POST("/avatar", AuthMiddleware(), handleUploadAvatar)
		}

		// --- Administración ---
		// Todas las rutas requieren autenticación + permisos de admin/moderador.
		// Los endpoints se dividen por nivel de acceso:
		//   - Moderador (5+): Listar, ver detalles, moderar contenido, cambiar estados
		//   - Admin (10): Cambiar roles, eliminar permanentemente
		admin := v1.Group("/admin")
		admin.Use(AuthMiddleware())
		{
			// Dashboard — Moderador (5+)
			admin.GET("/dashboard", RequireModerator(), handleAdminDashboard)

			// Gestión de Usuarios
			adminUsers := admin.Group("/users")
			{
				adminUsers.GET("", RequireModerator(), handleAdminListUsers)                     // Listar usuarios
				adminUsers.GET("/:id", RequireModerator(), handleAdminGetUser)                   // Detalle de usuario
				adminUsers.PATCH("/:id/status", RequireModerator(), handleAdminUpdateUserStatus) // Banear/suspender
				adminUsers.PATCH("/:id/role", RequireAdmin(), handleAdminUpdateUserRole)         // Cambiar rol (solo admin)
			}

			// Moderación de Videos
			adminVideos := admin.Group("/videos")
			{
				adminVideos.GET("", RequireModerator(), handleAdminListVideos)                     // Listar videos
				adminVideos.PATCH("/:id/status", RequireModerator(), handleAdminUpdateVideoStatus) // Ocultar/restaurar
				adminVideos.DELETE("/:id", RequireAdmin(), handleAdminDeleteVideo)                 // Eliminar permanente (solo admin)
			}

			// Moderación de Comentarios
			adminComments := admin.Group("/comments")
			{
				adminComments.GET("", RequireModerator(), handleAdminListComments)         // Listar comentarios
				adminComments.DELETE("/:id", RequireModerator(), handleAdminDeleteComment) // Eliminar comentario
			}
		}
	}

	// --- Configuración del puerto (compatible con Azure Container Apps / Fly.io) ---
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	// --- Graceful Shutdown ---
	srv := &http.Server{
		Addr:              ":" + port,
		Handler:           router,
		ReadTimeout:       15 * time.Second,
		WriteTimeout:      60 * time.Second, // Mayor para uploads de video
		IdleTimeout:       120 * time.Second,
		ReadHeaderTimeout: 5 * time.Second, // Protección contra Slowloris
	}

	// Canal para escuchar señales de sistema
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)

	go func() {
		Logger.Info("Servidor Go iniciado", "port", port, "url", "http://localhost:"+port)
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			Logger.Error("Error al iniciar el servidor", "error", err)
			os.Exit(1)
		}
	}()

	<-quit
	Logger.Info("Apagando servidor...")

	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	if err := srv.Shutdown(ctx); err != nil {
		Logger.Error("Fallo al apagar el servidor", "error", err)
		os.Exit(1)
	}
	Logger.Info("Servidor apagado correctamente")
}
