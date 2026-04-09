package main

import (
	"context"
	"time"
)

// --- Modelos de dominio ---

// User representa un usuario de la aplicación.
type User struct {
	ID           int       `json:"id"`
	Username     string    `json:"username"`
	Email        string    `json:"email"`
	Role         string    `json:"role,omitempty"` // Añadido para caché
	AvatarURL    string    `json:"avatar_url,omitempty"`
	Interests    []string  `json:"interests,omitempty"` // Añadido para Cold Start
	Bio          string    `json:"bio,omitempty"`
	Faculty      string    `json:"faculty,omitempty"`
	CvlacURL     string    `json:"cvlac_url,omitempty"`
	WebsiteURL   string    `json:"website_url,omitempty"`
	PasswordHash string    `json:"-"` // Nunca serializar
	CreatedAt    time.Time `json:"created_at"`
	LastLogin    time.Time `json:"last_login,omitempty"`
}

// Profile representa el perfil de un usuario.
type Profile struct {
	UserID     int    `json:"user_id"`
	Name       string `json:"name"`
	LastName   string `json:"last_name"`
	AvatarURL  string `json:"avatar_url,omitempty"`
	Bio        string `json:"bio,omitempty"`
	Faculty    string `json:"faculty,omitempty"`
	CvlacURL   string `json:"cvlac_url,omitempty"`
	WebsiteURL string `json:"website_url,omitempty"`
}

// PublicProfile representa la versión pública del perfil de un usuario, expuesta para que otros usuarios la vean.
type PublicProfile struct {
	UserID     int       `json:"user_id"`
	Username   string    `json:"username"`
	AvatarURL  string    `json:"avatar_url,omitempty"`
	Bio        string    `json:"bio,omitempty"`
	Faculty    string    `json:"faculty,omitempty"`
	CvlacURL   string    `json:"cvlac_url,omitempty"`
	WebsiteURL string    `json:"website_url,omitempty"`
	Role       string    `json:"role"`
	Interests  []string  `json:"interests,omitempty"`
}

// UpdateProfileRequest representa los datos enviados para actualizar el perfil.
type UpdateProfileRequest struct {
	Name       string `json:"name" binding:"required,max=100"`
	Bio        string `json:"bio" binding:"max=200"`
	Faculty    string `json:"faculty" binding:"max=100"`
	Role       string `json:"role"` // Opcional, requiere validación de acceso en backend
	CvlacURL   string `json:"cvlac_url" binding:"max=255"`
	WebsiteURL string `json:"website_url" binding:"max=255"`
}

// Video representa un contenido de video.
type Video struct {
	ID           int       `json:"id"`
	Title        string    `json:"title"`
	Description  string    `json:"description"`
	AuthorID     int       `json:"author_id"`
	AuthorName   string    `json:"author_name,omitempty"`
	VideoURL     string    `json:"video_url"`
	ThumbnailURL string    `json:"thumbnail_url"`
	Duration     int       `json:"duration_seconds,omitempty"`
	Size         int64     `json:"size_bytes,omitempty"`
	Likes        int       `json:"likes"`
	Comments     int       `json:"comments"`
	IsLiked      bool      `json:"is_liked"`
	IsBookmarked bool      `json:"is_bookmarked"`
	CreatedAt    time.Time `json:"created_at"`
	ContentType  string    `json:"content_type"`
}

// Comment representa un comentario en un video.
type Comment struct {
	ID        int       `json:"id"`
	UserID    int       `json:"user_id"`
	Username  string    `json:"username"`
	AvatarURL string    `json:"avatar_url,omitempty"`
	VideoID   int       `json:"video_id"`
	Text      string    `json:"text"`
	CreatedAt time.Time `json:"created_at"`
}

// Flashcard representa una tarjeta de estudio con frente y reverso.
type Flashcard struct {
	ID            int    `json:"id"`
	ContentID     int    `json:"content_id"`
	FrontText     string `json:"front_text"`
	BackText      string `json:"back_text"`
	FrontImageURL string `json:"front_image_url,omitempty"`
	BackImageURL  string `json:"back_image_url,omitempty"`
	// Campos heredados de contenidos
	Title       string    `json:"title,omitempty"`
	Description string    `json:"description,omitempty"`
	AuthorName  string    `json:"author_name,omitempty"`
	Likes       int       `json:"likes,omitempty"`
	CreatedAt   time.Time `json:"created_at,omitempty"`
}

// Poll representa una encuesta con opciones de respuesta.
type Poll struct {
	ID         int          `json:"id"`
	ContentID  int          `json:"content_id"`
	Question   string       `json:"question"`
	Options    []PollOption `json:"options"`
	TotalVotes int          `json:"total_votes"`
	HasVoted   bool         `json:"has_voted"`
	// Campos heredados de contenidos
	Title       string    `json:"title,omitempty"`
	Description string    `json:"description,omitempty"`
	AuthorName  string    `json:"author_name,omitempty"`
	CreatedAt   time.Time `json:"created_at,omitempty"`
}

// PollOption representa una opción de respuesta en una encuesta.
type PollOption struct {
	ID    int    `json:"id"`
	Text  string `json:"text"`
	Votes int    `json:"votes"`
	Order int    `json:"order"`
}

// TrendingTag representa un hashtag/tendencia popular.
type TrendingTag struct {
	Tag   string `json:"tag"`
	Count int    `json:"count"`
}

// --- Modelos de Administración ---

// AdminUser representa un usuario con información extendida para el panel de administración.
type AdminUser struct {
	ID            int       `json:"id"`
	Email         string    `json:"email"`
	Name          string    `json:"name"`
	LastName      string    `json:"last_name"`
	AvatarURL     string    `json:"avatar_url,omitempty"`
	RoleCode      string    `json:"role_code"`
	RoleName      string    `json:"role_name"`
	AccessLevel   int       `json:"access_level"`
	StatusCode    string    `json:"status_code"`
	StatusName    string    `json:"status_name"`
	CreatedAt     time.Time `json:"created_at"`
	LastLogin     time.Time `json:"last_login,omitempty"`
	VideosCount   int       `json:"videos_count"`
	CommentsCount int       `json:"comments_count"`
}

// AdminVideo representa un video con información extendida para moderación.
type AdminVideo struct {
	ID            int       `json:"id"`
	Title         string    `json:"title"`
	Description   string    `json:"description"`
	VideoURL      string    `json:"video_url"`
	ThumbnailURL  string    `json:"thumbnail_url,omitempty"`
	AuthorID      int       `json:"author_id"`
	AuthorName    string    `json:"author_name"`
	AuthorEmail   string    `json:"author_email"`
	StatusCode    string    `json:"status_code"`
	StatusName    string    `json:"status_name"`
	LikesCount    int       `json:"likes_count"`
	CommentsCount int       `json:"comments_count"`
	CreatedAt     time.Time `json:"created_at"`
}

// AdminComment representa un comentario con información extendida para moderación.
type AdminComment struct {
	ID         int       `json:"id"`
	Text       string    `json:"text"`
	UserID     int       `json:"user_id"`
	Username   string    `json:"username"`
	UserEmail  string    `json:"user_email"`
	VideoID    int       `json:"video_id"`
	VideoTitle string    `json:"video_title"`
	StatusCode string    `json:"status_code"`
	CreatedAt  time.Time `json:"created_at"`
}

// AdminStats representa las estadísticas globales del dashboard de administración.
type AdminStats struct {
	TotalUsers      int         `json:"total_users"`
	ActiveUsers     int         `json:"active_users"`
	BannedUsers     int         `json:"banned_users"`
	TotalVideos     int         `json:"total_videos"`
	PublishedVideos int         `json:"published_videos"`
	RemovedVideos   int         `json:"removed_videos"`
	TotalComments   int         `json:"total_comments"`
	TotalLikes      int         `json:"total_likes"`
	RecentSignups   int         `json:"recent_signups"` // Últimos 7 días
	TopRoles        []RoleCount `json:"top_roles"`
}

// RoleCount representa el conteo de usuarios por rol.
type RoleCount struct {
	RoleCode string `json:"role_code"`
	RoleName string `json:"role_name"`
	Count    int    `json:"count"`
}

// --- Modelos de Notificaciones ---

// Notification representa una notificación para un usuario.
type Notification struct {
	ID        int       `json:"id"`
	UserID    int       `json:"user_id"`
	Type      string    `json:"type"` // like, comment, follow, announcement
	Title     string    `json:"title"`
	Body      string    `json:"body"`
	ActorName string    `json:"actor_name,omitempty"` // Quien generó la notificación
	RefID     int       `json:"ref_id,omitempty"`     // ID del recurso relacionado (video, comentario)
	IsRead    bool      `json:"is_read"`
	CreatedAt time.Time `json:"created_at"`
}

// PaginatedResult es una respuesta genérica con paginación.
type PaginatedResult[T any] struct {
	Data       []T `json:"data"`
	Total      int `json:"total"`
	Page       int `json:"page"`
	PageSize   int `json:"page_size"`
	TotalPages int `json:"total_pages"`
}

// --- Interfaces de Repositorio ---
// Estas interfaces definen los contratos que cualquier implementación debe cumplir.
// Esto permite cambiar de PostgreSQL a MySQL, MongoDB, etc. sin modificar los handlers.

// UserRepository define las operaciones de persistencia para usuarios.
type UserRepository interface {
	// FindByID busca un usuario por su ID.
	FindByID(ctx context.Context, id int) (*User, error)

	// FindByEmail busca un usuario por su email.
	FindByEmail(ctx context.Context, email string) (*User, error)

	// Create crea un nuevo usuario y devuelve su ID.
	Create(ctx context.Context, user *User) (int, error)

	// UpdateLastLogin actualiza la fecha de último login.
	UpdateLastLogin(ctx context.Context, userID int) error

	// ExistsByID verifica si existe un usuario con el ID dado.
	ExistsByID(ctx context.Context, userID int) (bool, error)
}

// ProfileRepository define las operaciones de persistencia para perfiles.
type ProfileRepository interface {
	// FindByUserID busca el perfil de un usuario.
	FindByUserID(ctx context.Context, userID int) (*Profile, error)

	// Create crea un nuevo perfil.
	Create(ctx context.Context, profile *Profile) error

	// UpdateAvatar actualiza la URL del avatar.
	UpdateAvatar(ctx context.Context, userID int, avatarURL string) error

	// GetPublicProfile busca el perfil público de un usuario y lo acopla junto con su rol.
	GetPublicProfile(ctx context.Context, userID int) (*PublicProfile, error)
}

// VideoRepository define las operaciones de persistencia para videos.
type VideoRepository interface {
	// FindByID busca un video por su ID.
	FindByID(ctx context.Context, id int) (*Video, error)

	// Create crea un nuevo video y devuelve su ID.
	Create(ctx context.Context, video *Video) (int, error)

	// GetFeed obtiene videos para el feed con paginación.
	GetFeed(ctx context.Context, limit, offset int, userID *int) ([]Video, error)

	// Search busca videos por título o descripción.
	Search(ctx context.Context, query string, limit int, userID *int) ([]Video, error)

	// GetLikesCount obtiene el número de likes de un video.
	GetLikesCount(ctx context.Context, videoID int) (int, error)

	// ExistsByID verifica si existe un video con el ID dado.
	ExistsByID(ctx context.Context, videoID int) (bool, error)

	// GetByIDs obtiene varios videos por sus IDs preservando el orden.
	GetByIDs(ctx context.Context, ids []int) ([]Video, error)

	// GetPopular obtiene los videos más populares basados en interacciones (likes).
	GetPopular(ctx context.Context, limit int, userID *int) ([]Video, error)

	// GetSimilar obtiene videos similares a un ID específico (por ejemplo, el mismo autor o misma categoría).
	GetSimilar(ctx context.Context, videoID int, limit int, userID *int) ([]Video, error)

	// GetByAuthor obtiene todos los contenidos publicados por un autor específico.
	GetByAuthor(ctx context.Context, authorID int, userID *int) ([]Video, error)

	// GetTrends obtiene los hashtags más populares dentro de la aplicación.
	GetTrends(ctx context.Context, limit int) ([]TrendingTag, error)
}

// InteractionRepository define las operaciones de persistencia para interacciones (likes).
type InteractionRepository interface {
	// ToggleLike añade o quita un like. Devuelve si quedó con like y el nuevo conteo.
	ToggleLike(ctx context.Context, userID, videoID int) (isLiked bool, likesCount int, err error)

	// IsLiked verifica si un usuario dio like a un video.
	IsLiked(ctx context.Context, userID, videoID int) (bool, error)
}

// BookmarkRepository define las operaciones de persistencia para favoritos.
type BookmarkRepository interface {
	// Toggle añade o quita un bookmark. Devuelve el nuevo estado.
	Toggle(ctx context.Context, userID, videoID int) (isBookmarked bool, err error)

	// IsBookmarked verifica si un usuario tiene un video guardado.
	IsBookmarked(ctx context.Context, userID, videoID int) (bool, error)

	// GetUserBookmarks obtiene los videos guardados por un usuario.
	GetUserBookmarks(ctx context.Context, userID int, limit, offset int) ([]Video, error)
}

// CommentRepository define las operaciones de persistencia para comentarios.
type CommentRepository interface {
	// Create crea un nuevo comentario y devuelve su ID.
	Create(ctx context.Context, comment *Comment) (int, error)

	// GetByVideoID obtiene comentarios de un video con paginación.
	GetByVideoID(ctx context.Context, videoID int, limit int) ([]Comment, error)

	// Delete elimina un comentario (solo el autor o admin).
	Delete(ctx context.Context, commentID, userID int) error

	// CountByVideoID cuenta comentarios de un video.
	CountByVideoID(ctx context.Context, videoID int) (int, error)
}

// AdminRepository define las operaciones de persistencia para el servicio de administración.
type AdminRepository interface {
	// --- Gestión de Usuarios ---

	// GetUserAccessLevel obtiene el nivel de acceso del usuario (para middleware de admin).
	GetUserAccessLevel(ctx context.Context, userID int) (int, error)

	// ListUsers obtiene una lista paginada de usuarios con información extendida.
	ListUsers(ctx context.Context, page, pageSize int, search, roleFilter, statusFilter string) ([]AdminUser, int, error)

	// GetUserByID obtiene información completa de un usuario para el admin.
	GetUserByID(ctx context.Context, userID int) (*AdminUser, error)

	// UpdateUserStatus cambia el estado de un usuario (activo, suspendido, baneado).
	UpdateUserStatus(ctx context.Context, userID int, statusCode string) error

	// UpdateUserRole cambia el rol de un usuario (estudiante, moderador, admin).
	UpdateUserRole(ctx context.Context, userID int, roleCode string) error

	// --- Moderación de Contenido ---

	// ListVideos obtiene videos paginados con información extendida para moderación.
	ListVideos(ctx context.Context, page, pageSize int, search, statusFilter string) ([]AdminVideo, int, error)

	// UpdateVideoStatus cambia el estado de un video (publicado, eliminado, oculto).
	UpdateVideoStatus(ctx context.Context, videoID int, statusCode string) error

	// DeleteVideo elimina un video permanentemente (hard delete). Usa con precaución.
	DeleteVideo(ctx context.Context, videoID int) error

	// ListComments obtiene comentarios paginados para moderación.
	ListComments(ctx context.Context, page, pageSize int, search string) ([]AdminComment, int, error)

	// DeleteComment elimina un comentario por un administrador (sin verificar autoría).
	DeleteComment(ctx context.Context, commentID int) error

	// --- Estadísticas ---

	// GetDashboardStats obtiene estadísticas globales del dashboard de administración.
	GetDashboardStats(ctx context.Context) (*AdminStats, error)

	// --- Gestión de Roles ---

	// EnsureAdminRole verifica que exista el rol admin en la BD; lo crea si no existe.
	EnsureAdminRole(ctx context.Context) error
}

// NotificationRepository define las operaciones de persistencia para notificaciones.
type NotificationRepository interface {
	// Create crea una nueva notificación.
	Create(ctx context.Context, n *Notification) (int, error)

	// GetByUserID obtiene las notificaciones de un usuario con paginación.
	GetByUserID(ctx context.Context, userID, limit, offset int) ([]Notification, int, error)

	// MarkAsRead marca una notificación como leída.
	MarkAsRead(ctx context.Context, notificationID, userID int) error

	// MarkAllAsRead marca todas las notificaciones de un usuario como leídas.
	MarkAllAsRead(ctx context.Context, userID int) error

	// GetUnreadCount obtiene el número de notificaciones no leídas de un usuario.
	GetUnreadCount(ctx context.Context, userID int) (int, error)

	// EnsureTable crea la tabla de notificaciones si no existe.
	EnsureTable(ctx context.Context) error
}

// FlashcardRepository define las operaciones de persistencia para flashcards.
type FlashcardRepository interface {
	// Create crea una nueva flashcard y devuelve su ID.
	Create(ctx context.Context, f *Flashcard) (int, error)

	// GetByContentID obtiene la flashcard asociada a un contenido.
	GetByContentID(ctx context.Context, contentID int) (*Flashcard, error)
}

// PollRepository define las operaciones de persistencia para encuestas.
type PollRepository interface {
	// Create crea una encuesta con sus opciones.
	Create(ctx context.Context, p *Poll) (int, error)

	// GetByContentID obtiene una encuesta completa con opciones y totales.
	GetByContentID(ctx context.Context, contentID int) (*Poll, error)

	// Vote registra el voto de un usuario en una encuesta.
	Vote(ctx context.Context, pollID, optionID, userID int) error

	// HasVoted verifica si un usuario ya votó en una encuesta.
	HasVoted(ctx context.Context, pollID, userID int) (bool, error)
}

// --- Repositorio Agregado (Unit of Work) ---

// Repositories agrupa todos los repositorios para inyección de dependencias.
type Repositories struct {
	Users         UserRepository
	Profiles      ProfileRepository
	Videos        VideoRepository
	Interactions  InteractionRepository
	Bookmarks     BookmarkRepository
	Comments      CommentRepository
	Admin         AdminRepository
	Notifications NotificationRepository
	Flashcards    FlashcardRepository
	Polls         PollRepository
}

// NewRepositories crea una instancia de todos los repositorios usando PostgreSQL.
func NewRepositories() *Repositories {
	return &Repositories{
		Users:         NewPostgresUserRepository(),
		Profiles:      NewPostgresProfileRepository(),
		Videos:        NewPostgresVideoRepository(),
		Interactions:  NewPostgresInteractionRepository(),
		Bookmarks:     NewPostgresBookmarkRepository(),
		Comments:      NewPostgresCommentRepository(),
		Admin:         NewPostgresAdminRepository(),
		Notifications: NewPostgresNotificationRepository(),
		Flashcards:    NewPostgresFlashcardRepository(),
		Polls:         NewPostgresPollRepository(),
	}
}

// Repos es la instancia global de repositorios.
// Se inicializa en main.go después de conectar a la BD.
var Repos *Repositories
