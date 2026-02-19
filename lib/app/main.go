package main

import (
	"fmt"
	"log"
	"net/http"
	"os"
	"strings"
	"sync"
	"time"

	"github.com/cloudinary/cloudinary-go/v2"
	"github.com/gin-contrib/cors"
	"github.com/gin-gonic/gin"
	"github.com/golang-jwt/jwt/v4"
	"github.com/joho/godotenv"
	"golang.org/x/oauth2"
)

// Variables de configuración (se cargarán desde .env)
var JWT_SECRET_KEY string

// cld es la instancia del cliente de Cloudinary, accesible globalmente en el paquete.
var cld *cloudinary.Cloudinary

var googleOauthConfig *oauth2.Config

// --- "Base de datos" en memoria (para simulación) ---

var (
	users    = make(map[string]*User)     // No se usa fuera de main.go, se puede mantener en minúscula.
	Videos   = make(map[string]*Video)    // Exportado para handlers.go
	Comments = make(map[string][]Comment) // Exportado para handlers.go
	Mu       sync.Mutex                   // Exportado para handlers.go
	TempFeed []gin.H                      // Feed temporal en memoria
)

// Global variables to store IDs from reference tables, initialized in main.
var videoContentTypeID int
var imageContentTypeID int
var flashcardContentTypeID int
var publishedContentStateID int
var likeInteractionTypeID int

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
			return []byte(os.Getenv("JWT_SECRET_KEY")), nil
		})

		if err != nil || !token.Valid {
			log.Printf("Error al parsear o validar el token JWT: %v", err)
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid token"})
			c.Abort()
			return
		}

		if claims, ok := token.Claims.(jwt.MapClaims); ok {
			// El user_id se guarda como float64 en el token (tipo numérico por defecto en JSON/JWT).
			userID, ok := claims["user_id"].(float64)
			if !ok {
				c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid token claims"})
				return
			}
			log.Printf("Token válido. Usuario autenticado ID: %f", userID)
			c.Set("userID", userID)
			c.Next()
		} else {
			log.Println("Claims de token inválidos.")
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid token claims"})
			c.Next()
		}
	}
}

func main() {
	// Cargar variables de entorno desde el archivo .env
	// La ruta debe ser relativa al directorio desde donde se ejecuta `go run .` (lib/app).
	// Para llegar a la raíz del proyecto, necesitamos subir dos niveles.
	err := godotenv.Load("../../.env")
	if err != nil {
		log.Fatalf("Error al cargar el archivo .env: %v", err)
	}

	// --- Inicialización de la Base de Datos ---
	InitDB(os.Getenv("DB_CONNECTION_STRING"))
	// Nos aseguramos de cerrar la conexión a la BD cuando la aplicación termine.
	defer DB.Close()
	// -----------------------------------------

	// --- Inicialización de Cloudinary ---
	// Usamos '=' en lugar de ':=' porque 'cld' ya está declarada a nivel de paquete.
	cld, err = cloudinary.NewFromURL(os.Getenv("CLOUDINARY_URL"))
	if err != nil {
		log.Fatalf("ERROR: Fallo al inicializar Cloudinary: %v", err)
	}

	// --- Cargar IDs de referencia de la Base de Datos ---
	// Esto asegura que los handlers usen los IDs correctos de las tablas de referencia.
	err = DB.QueryRow("SELECT id_tipo_contenido FROM tipos_contenido WHERE codigo = $1", "video").Scan(&videoContentTypeID)
	if err != nil {
		log.Printf("ADVERTENCIA: Error al obtener id_tipo_contenido para 'video': %v", err)
	}
	log.Printf("ID de tipo de contenido 'video' cargado: %d", videoContentTypeID)

	// Cargar o crear ID para 'flashcard'
	err = DB.QueryRow("SELECT id_tipo_contenido FROM tipos_contenido WHERE codigo = $1", "flashcard").Scan(&flashcardContentTypeID)
	if err != nil {
		log.Printf("Tipo contenido 'flashcard' no encontrado, intentando crear...")
		err = DB.QueryRow("INSERT INTO tipos_contenido (codigo, nombre, descripcion) VALUES ('flashcard', 'Flashcard', 'Tarjeta de estudio') RETURNING id_tipo_contenido").Scan(&flashcardContentTypeID)
		if err != nil {
			log.Fatalf("ERROR: No se pudo crear el tipo de contenido 'flashcard': %v", err)
		}
	}
	log.Printf("ID de tipo de contenido 'flashcard' cargado: %d", flashcardContentTypeID)

	// Cargar o crear ID para 'image'
	err = DB.QueryRow("SELECT id_tipo_contenido FROM tipos_contenido WHERE codigo = $1", "image").Scan(&imageContentTypeID)
	if err != nil {
		log.Printf("Tipo contenido 'image' no encontrado, intentando crear...")
		err = DB.QueryRow("INSERT INTO tipos_contenido (codigo, nombre, descripcion) VALUES ('image', 'Imagen', 'Contenido de imagen') RETURNING id_tipo_contenido").Scan(&imageContentTypeID)
		if err != nil {
			log.Fatalf("ERROR: No se pudo crear el tipo de contenido 'image': %v", err)
		}
	}
	log.Printf("ID de tipo de contenido 'image' cargado: %d", imageContentTypeID)

	err = DB.QueryRow("SELECT id_estado_contenido FROM estados_contenido WHERE codigo = $1", "publicado").Scan(&publishedContentStateID)
	if err != nil {
		log.Printf("ADVERTENCIA: Error al obtener id_estado_contenido para 'publicado': %v", err)
	}
	log.Printf("ID de estado de contenido 'publicado' cargado: %d", publishedContentStateID)

	err = DB.QueryRow("SELECT id_tipo_interaccion FROM tipos_interaccion WHERE codigo = $1", "like").Scan(&likeInteractionTypeID)
	if err != nil {
		log.Printf("ADVERTENCIA: Error al obtener id_tipo_interaccion para 'like': %v", err)
	}
	log.Printf("ID de tipo de interacción 'like' cargado: %d", likeInteractionTypeID)

	JWT_SECRET_KEY = os.Getenv("JWT_SECRET_KEY")

	router := gin.Default()

	// --- AUMENTAR LÍMITE DE SUBIDA DE ARCHIVOS ---
	// Por defecto, Gin tiene un límite bajo (ej. 32MB). Lo aumentamos para permitir videos grandes.
	// 500 << 20 es una forma de calcular 500 MB (500 * 2^20 bytes).
	router.MaxMultipartMemory = 500 << 20 // 500 MB

	// Configuración de CORS para permitir peticiones desde Flutter (emulador/web)
	router.Use(cors.New(cors.Config{
		AllowOrigins:     []string{"*"}, // En producción, sé más específico.
		AllowMethods:     []string{"GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"},
		AllowHeaders:     []string{"Origin", "Content-Type", "Authorization"},
		ExposeHeaders:    []string{"Content-Length"},
		AllowCredentials: true,
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
			videos.POST("/:id/like", AuthMiddleware(), handleToggleLike) // Corregido: Se eliminó el middleware duplicado
			videos.POST("/:id/bookmark", AuthMiddleware(), handleToggleBookmark)
			videos.GET("/:id/comments", handleGetComments)
			videos.GET("/feed", handleGetVideosFeed) // Nueva ruta para el feed de videos
			videos.GET("/search", handleSearchVideos)
			videos.POST("/upload", AuthMiddleware(), handleUploadVideo)               // Nueva ruta para subir videos
			videos.POST("/upload-flashcard", AuthMiddleware(), handleUploadFlashcard) // Nueva ruta para flashcards
		}
		profile := api.Group("/profile")
		{
			profile.GET("/me", AuthMiddleware(), handleGetProfile)
			profile.POST("/avatar", AuthMiddleware(), handleUploadAvatar)
		}
	}

	log.Println("Servidor Go escuchando en http://localhost:8080")
	router.Run(":8080")
}
