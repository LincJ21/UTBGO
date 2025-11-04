package main

import (
	"context"
	"crypto/rand"
	"database/sql"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"strings"
	"sync"
	"time"

	"github.com/gin-contrib/cors"
	"github.com/gin-gonic/gin"
	"github.com/golang-jwt/jwt/v4"
	"golang.org/x/oauth2"
	"golang.org/x/oauth2/google"
)

// --- Configuración ---
// ¡¡¡IMPORTANTE!!!: Reemplaza estos valores con tus credenciales de Google.
const GOOGLE_CLIENT_ID = "TU_GOOGLE_CLIENT_ID"
const GOOGLE_CLIENT_SECRET = "TU_GOOGLE_CLIENT_SECRET"
const JWT_SECRET_KEY = "una-clave-secreta-muy-segura-y-larga" // ¡Cámbiala por una clave segura!

// Cadena de conexión a la base de datos PostgreSQL
const DB_CONNECTION_STRING = "postgresql://postgres:MYhcoFuYMGEFrSqgwFIcRWDDPJZswQhi@yamabiko.proxy.rlwy.net:29558/railway"

var googleOauthConfig *oauth2.Config

// --- Modelos de Datos ---

type User struct {
	ID        string `json:"id"`
	Username  string `json:"username"`
	Email     string `json:"email"`
	AvatarURL string `json:"avatarUrl"`
}

type Video struct {
	ID           string `json:"id"`
	Likes        int    `json:"likes"`
	IsLiked      bool   `json:"isLiked"`
	IsBookmarked bool   `json:"isBookmarked"`
}

type Comment struct {
	ID       string `json:"id"`
	UserID   string `json:"userId"`
	Username string `json:"username"`
	Text     string `json:"text"`
}

// --- "Base de datos" en memoria (para simulación) ---

var (
	users    = make(map[string]*User)
	videos   = make(map[string]*Video)
	comments = make(map[string][]Comment)
	mu       sync.Mutex
)

// --- Middleware de Autenticación ---

func AuthMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		authHeader := c.GetHeader("Authorization")
		if authHeader == "" {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Authorization header required"})
			c.Abort()
			return
		}

		tokenString := strings.TrimPrefix(authHeader, "Bearer ")
		if tokenString == authHeader {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Bearer token required"})
			c.Abort()
			return
		}

		token, err := jwt.Parse(tokenString, func(token *jwt.Token) (interface{}, error) {
			if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
				return nil, fmt.Errorf("unexpected signing method: %v", token.Header["alg"])
			}
			return []byte(JWT_SECRET_KEY), nil
		})

		if err != nil || !token.Valid {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid token"})
			c.Abort()
			return
		}

		if claims, ok := token.Claims.(jwt.MapClaims); ok {
			userID, ok := claims["user_id"].(string)
			if !ok {
				c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid token claims"})
				c.Abort()
				return
			}
			c.Set("userID", userID)
			c.Next()
		} else {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid token claims"})
			c.Abort()
		}
	}
}

// --- Handlers ---

func handleGoogleLogin(c *gin.Context) {
	// Genera un estado aleatorio para protección CSRF
	b := make([]byte, 16)
	rand.Read(b)
	oauthState := base64.URLEncoding.EncodeToString(b)
	// En una app real, guardarías esto en una cookie de sesión

	url := googleOauthConfig.AuthCodeURL(oauthState)
	c.Redirect(http.StatusTemporaryRedirect, url)
}

func handleGoogleCallback(c *gin.Context) {
	// En una app real, verificarías el 'state'
	code := c.Query("code")
	token, err := googleOauthConfig.Exchange(context.Background(), code)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to exchange token: " + err.Error()})
		return
	}

	response, err := http.Get("https://www.googleapis.com/oauth2/v2/userinfo?access_token=" + token.AccessToken)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to get user info: " + err.Error()})
		return
	}
	defer response.Body.Close()

	contents, err := io.ReadAll(response.Body)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to read user info: " + err.Error()})
		return
	}

	var googleUser struct {
		ID      string `json:"id"`
		Email   string `json:"email"`
		Name    string `json:"name"`
		Picture string `json:"picture"`
	}
	json.Unmarshal(contents, &googleUser)

	// --- Lógica de Base de Datos ---
	var userID int
	var user User

	// 1. Buscar si el usuario ya existe por su email.
	err = DB.QueryRowContext(c, "SELECT u.id_usuario, p.nombre, u.email, p.avatar_url FROM usuarios u JOIN perfiles p ON u.id_usuario = p.id_usuario WHERE u.email = $1", googleUser.Email).Scan(&userID, &user.Username, &user.Email, &user.AvatarURL)

	if err != nil {
		if err == sql.ErrNoRows {
			// 2. Si el usuario NO existe, lo creamos en una transacción.
			log.Printf("Usuario nuevo con email %s. Creando entrada en la BD.", googleUser.Email)

			tx, err := DB.BeginTx(c, nil)
			if err != nil {
				c.JSON(http.StatusInternalServerError, gin.H{"error": "Error al iniciar la transacción: " + err.Error()})
				return
			}
			defer tx.Rollback() // Rollback si algo falla

			// Insertar en 'usuarios' y obtener el nuevo id_usuario
			// Asumimos id_tipo_usuario=1 (estudiante?) y id_estado_usuario=1 (activo?)
			// ¡IMPORTANTE! Estos valores deben coincidir con los de tu tabla de tipos/estados.
			// Usamos un password hash falso porque el login es con Google.
			err = tx.QueryRowContext(c, "INSERT INTO usuarios (id_tipo_usuario, id_estado_usuario, email, password_hash, fecha_registro) VALUES (1, 1, $1, 'google-login', NOW()) RETURNING id_usuario", googleUser.Email).Scan(&userID)
			if err != nil {
				c.JSON(http.StatusInternalServerError, gin.H{"error": "Error al crear usuario: " + err.Error()})
				return
			}

			// Insertar en 'perfiles' usando el id_usuario que acabamos de obtener
			_, err = tx.ExecContext(c, "INSERT INTO perfiles (id_usuario, nombre, apellido, avatar_url) VALUES ($1, $2, '', $3)", userID, googleUser.Name, googleUser.Picture)
			if err != nil {
				c.JSON(http.StatusInternalServerError, gin.H{"error": "Error al crear perfil: " + err.Error()})
				return
			}

			if err = tx.Commit(); err != nil {
				c.JSON(http.StatusInternalServerError, gin.H{"error": "Error al confirmar la transacción: " + err.Error()})
				return
			}

			user = User{
				ID:        fmt.Sprintf("%d", userID),
				Username:  googleUser.Name,
				Email:     googleUser.Email,
				AvatarURL: googleUser.Picture,
			}

		} else {
			// Otro tipo de error con la base de datos
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Error al consultar la base de datos: " + err.Error()})
			return
		}
	} else {
		// 3. Si el usuario SÍ existe, actualizamos su último login y avatar.
		log.Printf("Usuario existente con email %s. Actualizando datos.", googleUser.Email)
		_, err = DB.ExecContext(c, "UPDATE usuarios SET ultimo_login = NOW() WHERE id_usuario = $1", userID)
		if err != nil {
			log.Printf("Advertencia: no se pudo actualizar ultimo_login para usuario %d: %v", userID, err)
		}
		_, err = DB.ExecContext(c, "UPDATE perfiles SET avatar_url = $1 WHERE id_usuario = $2", googleUser.Picture, userID)
		if err != nil {
			log.Printf("Advertencia: no se pudo actualizar avatar_url para usuario %d: %v", userID, err)
		}
		user.ID = fmt.Sprintf("%d", userID)
	}

	// Crear JWT
	jwtToken := jwt.NewWithClaims(jwt.SigningMethodHS256, jwt.MapClaims{
		"user_id": user.ID, // Usamos el ID de nuestra base de datos
		"exp":     time.Now().Add(time.Hour * 72).Unix(),
	})

	tokenString, err := jwtToken.SignedString([]byte(JWT_SECRET_KEY))
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create token"})
		return
	}

	// En una app real, redirigirías al cliente con el token
	// o el cliente haría una petición para obtenerlo.
	// Para simplificar, lo mostramos en el JSON.
	c.JSON(http.StatusOK, gin.H{"jwt_token": tokenString, "user": user})
}

func handleGetProfile(c *gin.Context) {
	userID, _ := c.Get("userID")

	var user User
	// Buscamos el perfil del usuario usando el ID del token JWT
	err := DB.QueryRowContext(c, "SELECT u.id_usuario, p.nombre, u.email, p.avatar_url FROM usuarios u JOIN perfiles p ON u.id_usuario = p.id_usuario WHERE u.id_usuario = $1", userID).Scan(&user.ID, &user.Username, &user.Email, &user.AvatarURL)

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

func ensureVideoExists(videoID string) *Video {
	mu.Lock()
	defer mu.Unlock()
	if _, ok := videos[videoID]; !ok {
		videos[videoID] = &Video{ID: videoID, Likes: 0, IsLiked: false, IsBookmarked: false}
	}
	return videos[videoID]
}

func handleToggleLike(c *gin.Context) {
	videoID := c.Param("id")
	video := ensureVideoExists(videoID)

	mu.Lock()
	defer mu.Unlock()

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
	video := ensureVideoExists(videoID)

	mu.Lock()
	defer mu.Unlock()

	video.IsBookmarked = !video.IsBookmarked

	log.Printf("Video %s toggled bookmark. New state: Bookmarked=%v", videoID, video.IsBookmarked)
	c.JSON(http.StatusOK, video)
}

func handleGetComments(c *gin.Context) {
	videoID := c.Param("id")

	mu.Lock()
	defer mu.Unlock()

	// Simular algunos comentarios si no existen
	if _, ok := comments[videoID]; !ok {
		comments[videoID] = []Comment{
			{ID: "c1", UserID: "user1", Username: "Usuario Uno", Text: "¡Qué buen video!"},
			{ID: "c2", UserID: "user2", Username: "Usuario Dos", Text: "Interesante perspectiva."},
		}
	}

	c.JSON(http.StatusOK, comments[videoID])
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

func main() {
	if GOOGLE_CLIENT_ID == "TU_GOOGLE_CLIENT_ID" || GOOGLE_CLIENT_SECRET == "TU_GOOGLE_CLIENT_SECRET" {
		log.Fatal("ERROR: Debes configurar tus credenciales de Google en las constantes GOOGLE_CLIENT_ID y GOOGLE_CLIENT_SECRET.")
	}

	// --- Inicialización de la Base de Datos ---
	InitDB(DB_CONNECTION_STRING)
	// Nos aseguramos de cerrar la conexión a la BD cuando la aplicación termine.
	defer DB.Close()
	// -----------------------------------------

	googleOauthConfig = &oauth2.Config{
		RedirectURL:  "http://localhost:8080/auth/google/callback",
		ClientID:     os.Getenv("GOOGLE_CLIENT_ID"),
		ClientSecret: os.Getenv("GOOGLE_CLIENT_SECRET"),
		Scopes:       []string{"https://www.googleapis.com/auth/userinfo.email", "https://www.googleapis.com/auth/userinfo.profile"},
		Endpoint:     google.Endpoint,
	}
	// Para facilitar, si las variables de entorno no están, usamos las constantes.
	if googleOauthConfig.ClientID == "" {
		googleOauthConfig.ClientID = GOOGLE_CLIENT_ID
	}
	if googleOauthConfig.ClientSecret == "" {
		googleOauthConfig.ClientSecret = GOOGLE_CLIENT_SECRET
	}

	router := gin.Default()

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
		authRoutes.GET("/login", handleGoogleLogin)
		authRoutes.GET("/callback", handleGoogleCallback)
	}

	// Rutas de la API (algunas protegidas)
	api := router.Group("/api")
	{
		videos := api.Group("/videos")
		{
			videos.POST("/:id/like", AuthMiddleware(), handleToggleLike)
			videos.POST("/:id/bookmark", AuthMiddleware(), handleToggleBookmark)
			videos.GET("/:id/comments", handleGetComments)
			videos.GET("/search", handleSearchVideos)
		}
	}

	// Ruta de perfil protegida
	router.GET("/profile/me", AuthMiddleware(), handleGetProfile) // Cambiado de /profile/1 a /profile/me

	log.Println("Servidor Go escuchando en http://localhost:8080")
	router.Run(":8080")
}
