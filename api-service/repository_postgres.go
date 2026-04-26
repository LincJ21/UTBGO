package main

import (
	"context"
	"database/sql"
	"fmt"
	"strings"
	"time"
)

// --- Implementación PostgreSQL de UserRepository ---

type PostgresUserRepository struct{}

func NewPostgresUserRepository() *PostgresUserRepository {
	return &PostgresUserRepository{}
}

func (r *PostgresUserRepository) FindByID(ctx context.Context, id int) (*User, error) {
	start := time.Now()
	var user User
	var avatarURL sql.NullString
	err := DB.QueryRowContext(ctx, `
		SELECT u.id_usuario, COALESCE(p.nombre || ' ' || p.apellido, u.email), u.email, p.avatar_url, u.fecha_registro, tu.codigo
		FROM usuarios u
		JOIN tipos_usuario tu ON u.id_tipo_usuario = tu.id_tipo_usuario
		LEFT JOIN perfiles p ON u.id_usuario = p.id_usuario
		WHERE u.id_usuario = $1`, id).Scan(&user.ID, &user.Username, &user.Email, &avatarURL, &user.CreatedAt, &user.Role)

	LogDB("SELECT", "usuarios", time.Since(start).Milliseconds(), err)

	if err == sql.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, fmt.Errorf("error finding user by ID: %w", err)
	}
	if avatarURL.Valid {
		user.AvatarURL = avatarURL.String
	}
	return &user, nil
}

func (r *PostgresUserRepository) FindByEmail(ctx context.Context, email string) (*User, error) {
	start := time.Now()
	var user User
	var avatarURL sql.NullString
	err := DB.QueryRowContext(ctx, `
		SELECT u.id_usuario, COALESCE(p.nombre || ' ' || p.apellido, u.email), u.email, p.avatar_url, u.password_hash, tu.codigo
		FROM usuarios u
		JOIN tipos_usuario tu ON u.id_tipo_usuario = tu.id_tipo_usuario
		LEFT JOIN perfiles p ON u.id_usuario = p.id_usuario
		WHERE u.email = $1`, email).Scan(&user.ID, &user.Username, &user.Email, &avatarURL, &user.PasswordHash, &user.Role)

	LogDB("SELECT", "usuarios", time.Since(start).Milliseconds(), err)

	if err == sql.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, fmt.Errorf("error finding user by email: %w", err)
	}
	if avatarURL.Valid {
		user.AvatarURL = avatarURL.String
	}
	return &user, nil
}

func (r *PostgresUserRepository) Create(ctx context.Context, user *User) (int, error) {
	start := time.Now()
	var userID int

	// Obtener IDs de referencia
	var studentTypeID, activeStateID int
	if err := DB.QueryRowContext(ctx, "SELECT id_tipo_usuario FROM tipos_usuario WHERE codigo = 'estudiante'").Scan(&studentTypeID); err != nil {
		return 0, fmt.Errorf("error finding student type: %w", err)
	}
	if err := DB.QueryRowContext(ctx, "SELECT id_estado_usuario FROM estados_usuario WHERE codigo = 'activo'").Scan(&activeStateID); err != nil {
		return 0, fmt.Errorf("error finding active state: %w", err)
	}

	err := DB.QueryRowContext(ctx, `
		INSERT INTO usuarios (id_tipo_usuario, id_estado_usuario, email, password_hash, fecha_registro)
		VALUES ($1, $2, $3, $4, NOW()) RETURNING id_usuario`,
		studentTypeID, activeStateID, user.Email, user.PasswordHash).Scan(&userID)

	LogDB("INSERT", "usuarios", time.Since(start).Milliseconds(), err)

	if err != nil {
		return 0, fmt.Errorf("error creating user: %w", err)
	}
	return userID, nil
}

func (r *PostgresUserRepository) UpdateLastLogin(ctx context.Context, userID int) error {
	start := time.Now()
	_, err := DB.ExecContext(ctx, "UPDATE usuarios SET ultimo_login = NOW() WHERE id_usuario = $1", userID)
	LogDB("UPDATE", "usuarios", time.Since(start).Milliseconds(), err)
	return err
}

func (r *PostgresUserRepository) ExistsByID(ctx context.Context, userID int) (bool, error) {
	var exists bool
	err := DB.QueryRowContext(ctx, "SELECT EXISTS(SELECT 1 FROM usuarios WHERE id_usuario = $1)", userID).Scan(&exists)
	return exists, err
}

// --- Implementación PostgreSQL de ProfileRepository ---

type PostgresProfileRepository struct{}

func NewPostgresProfileRepository() *PostgresProfileRepository {
	return &PostgresProfileRepository{}
}

// GetUserStats calcula las métricas vitales (likes, videos, views, seguidores) para el perfil de usuario.
// Se apoya en consultas directas y cruces de información de interacción y seguimiento.
func (r *PostgresProfileRepository) GetUserStats(ctx context.Context, userID int) (followers int, totalLikes int, totalViews int, totalVideos int, err error) {
	// Total de videos publicados
	err = DB.QueryRowContext(ctx, "SELECT COUNT(*) FROM contenidos WHERE id_autor = $1", userID).Scan(&totalVideos)
	if err != nil {
		return 0, 0, 0, 0, fmt.Errorf("error counting videos: %w", err)
	}

	// Total Likes recibidos
	err = DB.QueryRowContext(ctx, `
		SELECT COUNT(*) 
		FROM interacciones i
		JOIN contenidos c ON i.id_contenido = c.id_contenido
		JOIN tipos_interaccion ti ON i.id_tipo_interaccion = ti.id_tipo_interaccion
		WHERE c.id_autor = $1 AND ti.codigo = 'like'`, userID).Scan(&totalLikes)
	if err != nil {
		return totalVideos, 0, 0, 0, fmt.Errorf("error counting likes: %w", err)
	}

	// Followers (Calculados desde tabla seguidores)
	err = DB.QueryRowContext(ctx, "SELECT COUNT(*) FROM seguidores WHERE id_seguido = $1", userID).Scan(&followers)
	if err != nil {
		return 0, 0, 0, 0, fmt.Errorf("error counting followers: %w", err)
	}
	// Views (Vistas calculadas desde tracking_events en la misma BD Neon)
	err = DB.QueryRowContext(ctx, `
		SELECT COUNT(*) 
		FROM tracking_events 
		WHERE event_type = 'view' AND content_id IN (SELECT id_contenido FROM contenidos WHERE id_autor = $1)
	`, userID).Scan(&totalViews)
	if err != nil {
		Logger.Warn("No se pudo obtener total views", "error", err)
		totalViews = 0
		err = nil // Ignorar error para no fallar el request de perfil
	}

	return followers, totalLikes, totalViews, totalVideos, nil
}

// FollowUser inserta un registro en la tabla seguidores ignorando si ya lo sigue
func (r *PostgresProfileRepository) FollowUser(ctx context.Context, followerID, followedID int) error {
	if followerID == followedID {
		return fmt.Errorf("el usuario no puede seguirse a sí mismo")
	}
	_, err := DB.ExecContext(ctx, `
		INSERT INTO seguidores (id_seguidor, id_seguido) 
		VALUES ($1, $2) 
		ON CONFLICT DO NOTHING`, followerID, followedID)
	return err
}

// UnfollowUser elimina un registro en la tabla seguidores
func (r *PostgresProfileRepository) UnfollowUser(ctx context.Context, followerID, followedID int) error {
	_, err := DB.ExecContext(ctx, `
		DELETE FROM seguidores WHERE id_seguidor = $1 AND id_seguido = $2`, followerID, followedID)
	return err
}

func (r *PostgresProfileRepository) FindByUserID(ctx context.Context, userID int) (*Profile, error) {
	start := time.Now()
	var profile Profile
	var avatarURL, bio, faculty, cvlac, website sql.NullString

	err := DB.QueryRowContext(ctx, `
		SELECT id_usuario, nombre, COALESCE(apellido, ''), avatar_url, COALESCE(biografia, ''),
		       COALESCE(facultad, ''), cvlac_url, website_url
		FROM perfiles WHERE id_usuario = $1`, userID).Scan(
		&profile.UserID, &profile.Name, &profile.LastName, &avatarURL, &bio,
		&faculty, &cvlac, &website)

	LogDB("SELECT", "perfiles", time.Since(start).Milliseconds(), err)

	if err == sql.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	if avatarURL.Valid {
		profile.AvatarURL = avatarURL.String
	}
	if bio.Valid {
		profile.Bio = bio.String
	}
	if faculty.Valid {
		profile.Faculty = faculty.String
	}
	if cvlac.Valid {
		profile.CvlacURL = cvlac.String
	}
	if website.Valid {
		profile.WebsiteURL = website.String
	}
	return &profile, nil
}

func (r *PostgresProfileRepository) Create(ctx context.Context, profile *Profile) error {
	start := time.Now()
	_, err := DB.ExecContext(ctx, `
		INSERT INTO perfiles (id_usuario, nombre, apellido, avatar_url, biografia, facultad, cvlac_url, website_url)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8)`,
		profile.UserID, profile.Name, profile.LastName, profile.AvatarURL,
		profile.Bio, profile.Faculty, profile.CvlacURL, profile.WebsiteURL)

	LogDB("INSERT", "perfiles", time.Since(start).Milliseconds(), err)
	return err
}

func (r *PostgresProfileRepository) UpdateProfile(ctx context.Context, profile *Profile) error {
	start := time.Now()
	_, err := DB.ExecContext(ctx, `
		UPDATE perfiles
		SET nombre = $1, biografia = $2, facultad = $3, cvlac_url = $4, website_url = $5
		WHERE id_usuario = $6`,
		profile.Name, profile.Bio, profile.Faculty, profile.CvlacURL, profile.WebsiteURL, profile.UserID)
		
	LogDB("UPDATE", "perfiles", time.Since(start).Milliseconds(), err)
	return err
}

func (r *PostgresProfileRepository) UpdateAvatar(ctx context.Context, userID int, avatarURL string) error {
	start := time.Now()
	_, err := DB.ExecContext(ctx, "UPDATE perfiles SET avatar_url = $1 WHERE id_usuario = $2", avatarURL, userID)
	LogDB("UPDATE", "perfiles", time.Since(start).Milliseconds(), err)
	return err
}

func (r *PostgresProfileRepository) GetPublicProfile(ctx context.Context, userID int, requestorID *int) (*PublicProfile, error) {
	start := time.Now()
	var profile PublicProfile
	var avatarURL sql.NullString
	var bio, faculty, cvlac, website sql.NullString
	var interestsJSON sql.NullString
	var isFollowing bool

	err := DB.QueryRowContext(ctx, `
		SELECT 
			u.id_usuario, p.nombre || ' ' || p.apellido, p.avatar_url, 
			p.biografia, p.facultad, p.cvlac_url, p.website_url, 
			tu.codigo, array_to_json(p.intereses),
			COALESCE((SELECT EXISTS(SELECT 1 FROM seguidores WHERE id_seguidor = $1 AND id_seguido = $2)), false) AS is_following
		FROM usuarios u
		JOIN perfiles p ON u.id_usuario = p.id_usuario
		JOIN tipos_usuario tu ON u.id_tipo_usuario = tu.id_tipo_usuario
		WHERE u.id_usuario = $2`, requestorID, userID).Scan(
			&profile.UserID, &profile.Username, &avatarURL,
			&bio, &faculty, &cvlac, &website, 
			&profile.Role, &interestsJSON, &isFollowing)

	LogDB("SELECT", "perfiles_public", time.Since(start).Milliseconds(), err)

	if err == sql.ErrNoRows {
		return nil, nil // Not found
	}
	if err != nil {
		return nil, err
	}

	if avatarURL.Valid {
		profile.AvatarURL = avatarURL.String
	}
	if bio.Valid {
		profile.Bio = bio.String
	}
	if faculty.Valid {
		profile.Faculty = faculty.String
	}
	if cvlac.Valid {
		profile.CvlacURL = cvlac.String
	}
	if website.Valid {
		profile.WebsiteURL = website.String
	}
	
	profile.IsFollowing = isFollowing

	// Parsear JSON intereses en slice
	// Para uso público, asumo que sí se envían
	if interestsJSON.Valid && interestsJSON.String != "" {
		// En la app no usamos los interests públicos actualmente, pero los retornamos por completitud.
		profile.Interests = []string{}
	}

	return &profile, nil
}

// --- Implementación PostgreSQL de VideoRepository ---

type PostgresVideoRepository struct{}

func NewPostgresVideoRepository() *PostgresVideoRepository {
	return &PostgresVideoRepository{}
}

func (r *PostgresVideoRepository) FindByID(ctx context.Context, id int) (*Video, error) {
	start := time.Now()
	var video Video
	var thumbnail sql.NullString

	err := DB.QueryRowContext(ctx, `
		SELECT id_contenido, titulo, descripcion, url_contenido, COALESCE(url_thumbnail, ''), id_autor
		FROM contenidos WHERE id_contenido = $1`, id).Scan(
		&video.ID, &video.Title, &video.Description, &video.VideoURL, &thumbnail, &video.AuthorID)

	LogDB("SELECT", "contenidos", time.Since(start).Milliseconds(), err)

	if err == sql.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	if thumbnail.Valid {
		video.ThumbnailURL = thumbnail.String
	}
	return &video, nil
}

func (r *PostgresVideoRepository) Create(ctx context.Context, video *Video) (int, error) {
	start := time.Now()
	var videoID int

	typeID := videoContentTypeID
	if video.ContentType == "imagen" {
		typeID = imageContentTypeID
	} else if video.ContentType == "flashcard" {
		typeID = flashcardContentTypeID
	} else if video.ContentType == "encuesta" {
		typeID = pollContentTypeID
	}

	// Si la categoría está vacía, usar 'General' por defecto
	category := video.Category
	if category == "" {
		category = "General"
	}

	err := DB.QueryRowContext(ctx, `
		INSERT INTO contenidos (titulo, descripcion, id_autor, id_tipo_contenido, id_estado_contenido, url_contenido, url_thumbnail, categoria)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8) RETURNING id_contenido`,
		video.Title, video.Description, video.AuthorID, typeID, publishedContentStateID,
		video.VideoURL, video.ThumbnailURL, category).Scan(&videoID)

	LogDB("INSERT", "contenidos", time.Since(start).Milliseconds(), err)

	if err != nil {
		return 0, err
	}
	return videoID, nil
}

func (r *PostgresVideoRepository) GetFeed(ctx context.Context, limit, offset int, userID *int) ([]Video, error) {
	start := time.Now()

	// Si userID es 0 o nil, las banderas serán falsas por defecto
	idForFlags := 0
	if userID != nil {
		idForFlags = *userID
	}

	rows, err := DB.QueryContext(ctx, `
		SELECT 
			c.id_contenido, c.titulo, COALESCE(c.descripcion, ''), c.url_contenido, COALESCE(c.url_thumbnail, ''),
			tc.codigo as content_type,
			c.fecha_creacion,
			(SELECT COUNT(*) FROM interacciones WHERE id_contenido = c.id_contenido AND id_tipo_interaccion = $1) as likes,
			(SELECT COUNT(*) FROM comentarios co WHERE co.id_contenido = c.id_contenido) as comments,
			COALESCE(p.nombre || ' ' || COALESCE(p.apellido, ''), 'Usuario UTB') as author_name, 
			c.id_autor,
			COALESCE((SELECT TRUE FROM interacciones WHERE id_usuario = $5 AND id_contenido = c.id_contenido AND id_tipo_interaccion = $1 LIMIT 1), FALSE) as is_liked,
			COALESCE((SELECT TRUE FROM favoritos WHERE id_usuario = $5 AND id_contenido = c.id_contenido LIMIT 1), FALSE) as is_bookmarked,
			COALESCE(c.categoria, 'General') as categoria
		FROM contenidos c
		JOIN tipos_contenido tc ON c.id_tipo_contenido = tc.id_tipo_contenido
		LEFT JOIN perfiles p ON c.id_autor = p.id_usuario
		WHERE c.id_estado_contenido = $2
		ORDER BY c.fecha_creacion DESC
		LIMIT $3 OFFSET $4`,
		likeInteractionTypeID, publishedContentStateID, limit, offset, idForFlags)

	LogDB("SELECT", "contenidos_feed", time.Since(start).Milliseconds(), err)

	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var videos []Video
	for rows.Next() {
		var v Video
		if err := rows.Scan(&v.ID, &v.Title, &v.Description, &v.VideoURL, &v.ThumbnailURL, &v.ContentType, &v.CreatedAt, &v.Likes, &v.Comments, &v.AuthorName, &v.AuthorID, &v.IsLiked, &v.IsBookmarked, &v.Category); err != nil {
			Logger.Warn("Error scanning feed row", "error", err)
			continue
		}
		videos = append(videos, v)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("error iterating feed rows: %w", err)
	}
	return videos, nil
}

func (r *PostgresVideoRepository) GetByAuthor(ctx context.Context, authorID int, userID *int) ([]Video, error) {
	start := time.Now()

	// Si userID es 0 o nil, las banderas serán falsas por defecto
	idForFlags := 0
	if userID != nil {
		idForFlags = *userID
	}

	// Obtiene todos los contenidos creados por el autor, ordenados del más reciente al más antiguo.
	// Por ahora limitamos a 50 pero se podría paginar en el futuro.
	rows, err := DB.QueryContext(ctx, `
		SELECT 
			c.id_contenido, c.titulo, COALESCE(c.descripcion, ''), c.url_contenido, COALESCE(c.url_thumbnail, ''),
			tc.codigo as content_type,
			c.fecha_creacion,
			(SELECT COUNT(*) FROM interacciones WHERE id_contenido = c.id_contenido AND id_tipo_interaccion = $1) as likes,
			(SELECT COUNT(*) FROM comentarios co WHERE co.id_contenido = c.id_contenido) as comments,
			COALESCE(p.nombre || ' ' || COALESCE(p.apellido, ''), 'Usuario UTB') as author_name, 
			c.id_autor,
			COALESCE((SELECT TRUE FROM interacciones WHERE id_usuario = $4 AND id_contenido = c.id_contenido AND id_tipo_interaccion = $1 LIMIT 1), FALSE) as is_liked,
			COALESCE((SELECT TRUE FROM favoritos WHERE id_usuario = $4 AND id_contenido = c.id_contenido LIMIT 1), FALSE) as is_bookmarked,
			COALESCE(c.categoria, 'General') as categoria
		FROM contenidos c
		JOIN tipos_contenido tc ON c.id_tipo_contenido = tc.id_tipo_contenido
		LEFT JOIN perfiles p ON c.id_autor = p.id_usuario
		WHERE c.id_estado_contenido = $2 AND c.id_autor = $3
		ORDER BY c.fecha_creacion DESC
		LIMIT 50`,
		likeInteractionTypeID, publishedContentStateID, authorID, idForFlags)

	LogDB("SELECT", "contenidos_by_author", time.Since(start).Milliseconds(), err)

	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var videos []Video
	for rows.Next() {
		var v Video
		if err := rows.Scan(&v.ID, &v.Title, &v.Description, &v.VideoURL, &v.ThumbnailURL, &v.ContentType, &v.CreatedAt, &v.Likes, &v.Comments, &v.AuthorName, &v.AuthorID, &v.IsLiked, &v.IsBookmarked, &v.Category); err != nil {
			Logger.Warn("Error scanning author publications row", "error", err)
			continue
		}
		videos = append(videos, v)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("error iterating author publications: %w", err)
	}
	return videos, nil
}

func (r *PostgresVideoRepository) Search(ctx context.Context, query string, dateFilter string, authorFilter string, categoryFilter string, limit int, userID *int) ([]Video, error) {
	start := time.Now()

	// Si el query es '*', buscar todo (usado al filtrar solo por categoría)
	var searchQuery string
	if query == "*" {
		searchQuery = "%"
	} else {
		searchQuery = "%" + strings.ToLower(query) + "%"
	}

	// Si userID es 0 o nil, las banderas serán falsas por defecto
	idForFlags := 0
	if userID != nil {
		idForFlags = *userID
	}

	baseSQL := `
		SELECT 
			c.id_contenido, c.titulo, COALESCE(c.descripcion, ''), c.url_contenido, COALESCE(c.url_thumbnail, ''),
			tc.codigo as content_type,
			c.fecha_creacion,
			(SELECT COUNT(*) FROM interacciones WHERE id_contenido = c.id_contenido AND id_tipo_interaccion = $1) as likes,
			(SELECT COUNT(*) FROM comentarios co WHERE co.id_contenido = c.id_contenido) as comments,
			COALESCE(p.nombre || ' ' || COALESCE(p.apellido, ''), 'Usuario UTB') as author_name, 
			c.id_autor,
			COALESCE((SELECT TRUE FROM interacciones WHERE id_usuario = $4 AND id_contenido = c.id_contenido AND id_tipo_interaccion = $1 LIMIT 1), FALSE) as is_liked,
			COALESCE((SELECT TRUE FROM favoritos WHERE id_usuario = $4 AND id_contenido = c.id_contenido LIMIT 1), FALSE) as is_bookmarked,
			COALESCE(c.categoria, 'General') as categoria
		FROM contenidos c
		JOIN tipos_contenido tc ON c.id_tipo_contenido = tc.id_tipo_contenido
		LEFT JOIN perfiles p ON c.id_autor = p.id_usuario
		WHERE c.id_estado_contenido = $2 
		  AND (LOWER(c.titulo) LIKE $3 OR LOWER(c.descripcion) LIKE $3)`

	args := []interface{}{likeInteractionTypeID, publishedContentStateID, searchQuery, idForFlags}
	argIdx := 5

	if dateFilter != "" {
		switch dateFilter {
		case "today":
			baseSQL += ` AND c.fecha_creacion >= NOW() - INTERVAL '1 day'`
		case "week":
			baseSQL += ` AND c.fecha_creacion >= NOW() - INTERVAL '7 days'`
		case "month":
			baseSQL += ` AND c.fecha_creacion >= NOW() - INTERVAL '30 days'`
		}
	}

	if authorFilter != "" {
		baseSQL += fmt.Sprintf(` AND LOWER(COALESCE(p.nombre || ' ' || COALESCE(p.apellido, ''), '')) LIKE $%d`, argIdx)
		args = append(args, "%"+strings.ToLower(authorFilter)+"%")
		argIdx++
	}

	if categoryFilter != "" {
		baseSQL += fmt.Sprintf(` AND c.categoria = $%d`, argIdx)
		args = append(args, categoryFilter)
		argIdx++
	}

	baseSQL += fmt.Sprintf(` ORDER BY c.fecha_creacion DESC LIMIT $%d`, argIdx)
	args = append(args, limit)

	rows, err := DB.QueryContext(ctx, baseSQL, args...)

	LogDB("SEARCH", "contenidos", time.Since(start).Milliseconds(), err)

	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var videos []Video
	for rows.Next() {
		var v Video
		if err := rows.Scan(&v.ID, &v.Title, &v.Description, &v.VideoURL, &v.ThumbnailURL, &v.ContentType, &v.CreatedAt, &v.Likes, &v.Comments, &v.AuthorName, &v.AuthorID, &v.IsLiked, &v.IsBookmarked, &v.Category); err != nil {
			Logger.Warn("Error scanning search result row", "error", err)
			continue
		}
		videos = append(videos, v)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("error iterating search rows: %w", err)
	}
	return videos, nil
}

func (r *PostgresVideoRepository) GetLikesCount(ctx context.Context, videoID int) (int, error) {
	var count int
	err := DB.QueryRowContext(ctx, "SELECT COUNT(*) FROM interacciones WHERE id_contenido = $1 AND id_tipo_interaccion = $2",
		videoID, likeInteractionTypeID).Scan(&count)
	return count, err
}

func (r *PostgresVideoRepository) ExistsByID(ctx context.Context, videoID int) (bool, error) {
	var exists bool
	err := DB.QueryRowContext(ctx, "SELECT EXISTS(SELECT 1 FROM contenidos WHERE id_contenido = $1)", videoID).Scan(&exists)
	return exists, err
}

func (r *PostgresVideoRepository) GetByIDs(ctx context.Context, ids []int) ([]Video, error) {
	if len(ids) == 0 {
		return []Video{}, nil
	}

	start := time.Now()
	// Usar ANY($1) y array_position para mantener el orden de ranking de Gorse
	rows, err := DB.QueryContext(ctx, `
		SELECT 
			c.id_contenido, c.titulo, COALESCE(c.descripcion, ''), c.url_contenido, COALESCE(c.url_thumbnail, ''),
			tc.codigo as content_type,
			c.fecha_creacion,
			(SELECT COUNT(*) FROM interacciones WHERE id_contenido = c.id_contenido AND id_tipo_interaccion = $1) as likes,
			(SELECT COUNT(*) FROM comentarios co WHERE co.id_contenido = c.id_contenido) as comments,
			COALESCE(p.nombre, 'Usuario') as author_name, c.id_autor
		FROM contenidos c
		JOIN tipos_contenido tc ON c.id_tipo_contenido = tc.id_tipo_contenido
		LEFT JOIN perfiles p ON c.id_autor = p.id_usuario
		WHERE c.id_contenido = ANY($2) AND c.id_estado_contenido = $3
		ORDER BY array_position($2, CAST(c.id_contenido AS BIGINT))`,
		likeInteractionTypeID, ids, publishedContentStateID)

	LogDB("SELECT_BATCH", "contenidos", time.Since(start).Milliseconds(), err)

	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var videos []Video
	for rows.Next() {
		var v Video
		if err := rows.Scan(&v.ID, &v.Title, &v.Description, &v.VideoURL, &v.ThumbnailURL, &v.ContentType, &v.CreatedAt, &v.Likes, &v.Comments, &v.AuthorName, &v.AuthorID); err != nil {
			Logger.Warn("Error scanning batch row", "error", err)
			continue
		}
		videos = append(videos, v)
	}
	return videos, rows.Err()
}

func (r *PostgresVideoRepository) GetPopular(ctx context.Context, limit int, userID *int) ([]Video, error) {
	start := time.Now()

	// Si userID es 0 o nil, las banderas serán falsas por defecto
	idForFlags := 0
	if userID != nil {
		idForFlags = *userID
	}

	rows, err := DB.QueryContext(ctx, `
		SELECT 
			c.id_contenido, c.titulo, COALESCE(c.descripcion, ''), c.url_contenido, COALESCE(c.url_thumbnail, ''),
			tc.codigo as content_type,
			c.fecha_creacion,
			(SELECT COUNT(*) FROM interacciones WHERE id_contenido = c.id_contenido AND id_tipo_interaccion = $1) as likes,
			(SELECT COUNT(*) FROM comentarios co WHERE co.id_contenido = c.id_contenido) as comments,
			COALESCE(p.nombre || ' ' || COALESCE(p.apellido, ''), 'Usuario UTB') as author_name, 
			c.id_autor,
			COALESCE((SELECT TRUE FROM interacciones WHERE id_usuario = $4 AND id_contenido = c.id_contenido AND id_tipo_interaccion = $1 LIMIT 1), FALSE) as is_liked,
			COALESCE((SELECT TRUE FROM favoritos WHERE id_usuario = $4 AND id_contenido = c.id_contenido LIMIT 1), FALSE) as is_bookmarked
		FROM contenidos c
		JOIN tipos_contenido tc ON c.id_tipo_contenido = tc.id_tipo_contenido
		LEFT JOIN perfiles p ON c.id_autor = p.id_usuario
		WHERE c.id_estado_contenido = $2
		ORDER BY likes DESC, c.fecha_creacion DESC
		LIMIT $3`,
		likeInteractionTypeID, publishedContentStateID, limit, idForFlags)

	LogDB("SELECT", "contenidos_popular", time.Since(start).Milliseconds(), err)

	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var videos []Video
	for rows.Next() {
		var v Video
		if err := rows.Scan(&v.ID, &v.Title, &v.Description, &v.VideoURL, &v.ThumbnailURL, &v.ContentType, &v.CreatedAt, &v.Likes, &v.Comments, &v.AuthorName, &v.AuthorID, &v.IsLiked, &v.IsBookmarked); err != nil {
			Logger.Warn("Error scanning popular result row", "error", err)
			continue
		}
		videos = append(videos, v)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("error iterating popular rows: %w", err)
	}
	return videos, nil
}

func (r *PostgresVideoRepository) GetSimilar(ctx context.Context, videoID int, limit int, userID *int) ([]Video, error) {
	start := time.Now()

	// Primero buscamos el autor del video para buscar otros videos del mismo autor
	var authorID int
	err := DB.QueryRowContext(ctx, "SELECT id_autor FROM contenidos WHERE id_contenido = $1", videoID).Scan(&authorID)
	if err != nil {
		return nil, err // Fallback or handle error
	}

	// Si userID es 0 o nil, las banderas serán falsas por defecto
	idForFlags := 0
	if userID != nil {
		idForFlags = *userID
	}

	rows, err := DB.QueryContext(ctx, `
		SELECT 
			c.id_contenido, c.titulo, COALESCE(c.descripcion, ''), c.url_contenido, COALESCE(c.url_thumbnail, ''),
			tc.codigo as content_type,
			(SELECT COUNT(*) FROM interacciones WHERE id_contenido = c.id_contenido AND id_tipo_interaccion = $1) as likes,
			(SELECT COUNT(*) FROM comentarios co WHERE co.id_contenido = c.id_contenido) as comments,
			COALESCE((SELECT TRUE FROM interacciones WHERE id_usuario = $5 AND id_contenido = c.id_contenido AND id_tipo_interaccion = $1 LIMIT 1), FALSE) as is_liked,
			COALESCE((SELECT TRUE FROM favoritos WHERE id_usuario = $5 AND id_contenido = c.id_contenido LIMIT 1), FALSE) as is_bookmarked
		FROM contenidos c
		JOIN tipos_contenido tc ON c.id_tipo_contenido = tc.id_tipo_contenido
		WHERE c.id_autor = $2 AND c.id_contenido != $3 AND c.id_estado_contenido = $4
		ORDER BY c.fecha_creacion DESC
		LIMIT $6`, likeInteractionTypeID, authorID, videoID, publishedContentStateID, idForFlags, limit)

	LogDB("SELECT_SIMILAR", "contenidos", time.Since(start).Milliseconds(), err)

	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var videos []Video
	for rows.Next() {
		var v Video
		if err := rows.Scan(&v.ID, &v.Title, &v.Description, &v.VideoURL, &v.ThumbnailURL, &v.ContentType, &v.Likes, &v.Comments, &v.IsLiked, &v.IsBookmarked); err != nil {
			Logger.Warn("Error scanning similar result row", "error", err)
			continue
		}
		videos = append(videos, v)
	}
	return videos, rows.Err()
}

// --- Implementación PostgreSQL de InteractionRepository ---

func (r *PostgresVideoRepository) GetTrends(ctx context.Context, limit int) ([]TrendingTag, error) {
	start := time.Now()
	
	// Extraer hashtags dinámicamente de las descripciones publicadas usando regexp_matches
	rows, err := DB.QueryContext(ctx, `
		SELECT word[1] as tag, count(*) 
		FROM (
			SELECT regexp_matches(descripcion, '#[a-zA-Z0-9_]+', 'g') as word 
			FROM contenidos 
			WHERE id_estado_contenido = $1 AND descripcion IS NOT NULL
		) sub 
		GROUP BY word 
		ORDER BY count DESC 
		LIMIT $2`,
		publishedContentStateID, limit)

	LogDB("GET_TRENDS", "contenidos", time.Since(start).Milliseconds(), err)

	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var trends []TrendingTag
	for rows.Next() {
		var t TrendingTag
		if err := rows.Scan(&t.Tag, &t.Count); err != nil {
			Logger.Warn("Error scanning trend row", "error", err)
			continue
		}
		trends = append(trends, t)
	}
	return trends, rows.Err()
}

type PostgresInteractionRepository struct{}

func NewPostgresInteractionRepository() *PostgresInteractionRepository {
	return &PostgresInteractionRepository{}
}

func (r *PostgresInteractionRepository) ToggleLike(ctx context.Context, userID, videoID int) (bool, int, error) {
	start := time.Now()

	// Verificar si ya existe el like
	var interactionID int
	err := DB.QueryRowContext(ctx, `
		SELECT id_interaccion FROM interacciones 
		WHERE id_usuario = $1 AND id_contenido = $2 AND id_tipo_interaccion = $3`,
		userID, videoID, likeInteractionTypeID).Scan(&interactionID)

	isLiked := false
	if err == sql.ErrNoRows {
		// No existe, crear like
		_, err = DB.ExecContext(ctx, `
			INSERT INTO interacciones (id_usuario, id_contenido, id_tipo_interaccion) VALUES ($1, $2, $3)`,
			userID, videoID, likeInteractionTypeID)
		isLiked = true
	} else if err == nil {
		// Existe, eliminar like
		_, err = DB.ExecContext(ctx, "DELETE FROM interacciones WHERE id_interaccion = $1", interactionID)
		isLiked = false
	}

	LogDB("TOGGLE_LIKE", "interacciones", time.Since(start).Milliseconds(), err)

	if err != nil {
		return false, 0, err
	}

	// Obtener nuevo conteo
	likesCount, _ := Repos.Videos.GetLikesCount(ctx, videoID)
	return isLiked, likesCount, nil
}

func (r *PostgresInteractionRepository) IsLiked(ctx context.Context, userID, videoID int) (bool, error) {
	var exists bool
	err := DB.QueryRowContext(ctx, `
		SELECT EXISTS(SELECT 1 FROM interacciones WHERE id_usuario = $1 AND id_contenido = $2 AND id_tipo_interaccion = $3)`,
		userID, videoID, likeInteractionTypeID).Scan(&exists)
	return exists, err
}

// --- Implementación PostgreSQL de BookmarkRepository ---

type PostgresBookmarkRepository struct{}

func NewPostgresBookmarkRepository() *PostgresBookmarkRepository {
	return &PostgresBookmarkRepository{}
}

func (r *PostgresBookmarkRepository) Toggle(ctx context.Context, userID, videoID int) (bool, error) {
	start := time.Now()

	var favoriteID int
	err := DB.QueryRowContext(ctx, "SELECT id_favorito FROM favoritos WHERE id_usuario = $1 AND id_contenido = $2",
		userID, videoID).Scan(&favoriteID)

	isBookmarked := false
	if err == sql.ErrNoRows {
		_, err = DB.ExecContext(ctx, "INSERT INTO favoritos (id_usuario, id_contenido, carpeta) VALUES ($1, $2, 'guardados')",
			userID, videoID)
		isBookmarked = true
	} else if err == nil {
		_, err = DB.ExecContext(ctx, "DELETE FROM favoritos WHERE id_favorito = $1", favoriteID)
		isBookmarked = false
	}

	LogDB("TOGGLE_BOOKMARK", "favoritos", time.Since(start).Milliseconds(), err)
	return isBookmarked, err
}

func (r *PostgresBookmarkRepository) IsBookmarked(ctx context.Context, userID, videoID int) (bool, error) {
	var exists bool
	err := DB.QueryRowContext(ctx, "SELECT EXISTS(SELECT 1 FROM favoritos WHERE id_usuario = $1 AND id_contenido = $2)",
		userID, videoID).Scan(&exists)
	return exists, err
}

func (r *PostgresBookmarkRepository) GetUserBookmarks(ctx context.Context, userID int, limit, offset int) ([]Video, error) {
	rows, err := DB.QueryContext(ctx, `
		SELECT 
			c.id_contenido, c.titulo, COALESCE(c.descripcion, ''), c.url_contenido, COALESCE(c.url_thumbnail, ''), 
			tc.codigo as content_type,
			COALESCE(p.nombre || ' ' || COALESCE(p.apellido, ''), 'Usuario UTB') as author_name,
			c.id_autor,
			COALESCE((SELECT TRUE FROM interacciones WHERE id_usuario = $1 AND id_contenido = c.id_contenido AND id_tipo_interaccion = $4 LIMIT 1), FALSE) as is_liked,
			TRUE as is_bookmarked
		FROM favoritos f
		JOIN contenidos c ON f.id_contenido = c.id_contenido
		JOIN tipos_contenido tc ON c.id_tipo_contenido = tc.id_tipo_contenido
		LEFT JOIN perfiles p ON c.id_autor = p.id_usuario
		WHERE f.id_usuario = $1
		ORDER BY f.fecha_creacion DESC
		LIMIT $2 OFFSET $3`, userID, limit, offset, likeInteractionTypeID)

	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var videos []Video
	for rows.Next() {
		var v Video
		if err := rows.Scan(&v.ID, &v.Title, &v.Description, &v.VideoURL, &v.ThumbnailURL, &v.ContentType, &v.AuthorName, &v.AuthorID, &v.IsLiked, &v.IsBookmarked); err != nil {
			Logger.Warn("Error scanning bookmark row", "error", err)
			continue
		}
		videos = append(videos, v)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("error iterating bookmark rows: %w", err)
	}
	return videos, nil
}

// --- Implementación PostgreSQL de CommentRepository ---

type PostgresCommentRepository struct{}

func NewPostgresCommentRepository() *PostgresCommentRepository {
	return &PostgresCommentRepository{}
}

func (r *PostgresCommentRepository) Create(ctx context.Context, comment *Comment) (int, error) {
	start := time.Now()
	var commentID int

	err := DB.QueryRowContext(ctx, `
		INSERT INTO comentarios (id_usuario, id_contenido, texto, id_estado_general)
		VALUES ($1, $2, $3, $4) RETURNING id_comentario`,
		comment.UserID, comment.VideoID, comment.Text, activeCommentStateID).Scan(&commentID)

	LogDB("INSERT", "comentarios", time.Since(start).Milliseconds(), err)
	return commentID, err
}

func (r *PostgresCommentRepository) GetByVideoID(ctx context.Context, videoID int, limit int) ([]Comment, error) {
	start := time.Now()

	rows, err := DB.QueryContext(ctx, `
		SELECT c.id_comentario, c.texto, c.fecha_creacion, 
		       u.id_usuario, COALESCE(p.nombre || ' ' || p.apellido, u.email) as username,
		       COALESCE(p.avatar_url, '') as avatar_url
		FROM comentarios c
		JOIN usuarios u ON c.id_usuario = u.id_usuario
		LEFT JOIN perfiles p ON u.id_usuario = p.id_usuario
		WHERE c.id_contenido = $1 AND c.id_estado_general = $2
		ORDER BY c.fecha_creacion DESC
		LIMIT $3`, videoID, activeCommentStateID, limit)

	LogDB("SELECT", "comentarios", time.Since(start).Milliseconds(), err)

	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var comments []Comment
	for rows.Next() {
		var c Comment
		if err := rows.Scan(&c.ID, &c.Text, &c.CreatedAt, &c.UserID, &c.Username, &c.AvatarURL); err != nil {
			Logger.Warn("Error scanning comment row", "error", err)
			continue
		}
		c.VideoID = videoID
		comments = append(comments, c)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("error iterating comment rows: %w", err)
	}
	return comments, nil
}

func (r *PostgresCommentRepository) Delete(ctx context.Context, commentID, userID int) error {
	start := time.Now()
	result, err := DB.ExecContext(ctx, "DELETE FROM comentarios WHERE id_comentario = $1 AND id_usuario = $2",
		commentID, userID)

	LogDB("DELETE", "comentarios", time.Since(start).Milliseconds(), err)

	if err != nil {
		return err
	}

	rows, _ := result.RowsAffected()
	if rows == 0 {
		return fmt.Errorf("comment not found or not authorized")
	}
	return nil
}

// GetConnections devuelve las dos listas: gente que sigue a userID (Followers) y gente a la que userID sigue (Following).
func (r *PostgresProfileRepository) GetConnections(ctx context.Context, userID int, requestorID *int) (*ConnectionsResponse, error) {
	start := time.Now()
	resp := &ConnectionsResponse{
		Followers: make([]ConnectionUser, 0),
		Following: make([]ConnectionUser, 0),
	}

	// 1. Obtener Seguidores (Los que siguen a userID)
	queryFollowers := `
		SELECT u.id_usuario, p.nombre || ' ' || p.apellido, p.avatar_url, tu.codigo,
			COALESCE((SELECT EXISTS(SELECT 1 FROM seguidores WHERE id_seguidor = $2 AND id_seguido = u.id_usuario)), false) AS is_following
		FROM seguidores s
		JOIN usuarios u ON s.id_seguidor = u.id_usuario
		JOIN perfiles p ON u.id_usuario = p.id_usuario
		JOIN tipos_usuario tu ON u.id_tipo_usuario = tu.id_tipo_usuario
		WHERE s.id_seguido = $1
		ORDER BY s.fecha_creacion DESC
	`
	rowsFollowers, err := DB.QueryContext(ctx, queryFollowers, userID, requestorID)
	if err != nil {
		return nil, fmt.Errorf("error obteniendo followers: %w", err)
	}
	defer rowsFollowers.Close()

	for rowsFollowers.Next() {
		var user ConnectionUser
		var avatarURL sql.NullString
		if err := rowsFollowers.Scan(&user.UserID, &user.Username, &avatarURL, &user.Role, &user.IsFollowing); err != nil {
			return nil, err
		}
		if avatarURL.Valid {
			user.AvatarURL = avatarURL.String
		}
		resp.Followers = append(resp.Followers, user)
	}

	// 2. Obtener Seguidos (A los que userID sigue)
	queryFollowing := `
		SELECT u.id_usuario, p.nombre || ' ' || p.apellido, p.avatar_url, tu.codigo,
			COALESCE((SELECT EXISTS(SELECT 1 FROM seguidores WHERE id_seguidor = $2 AND id_seguido = u.id_usuario)), false) AS is_following
		FROM seguidores s
		JOIN usuarios u ON s.id_seguido = u.id_usuario
		JOIN perfiles p ON u.id_usuario = p.id_usuario
		JOIN tipos_usuario tu ON u.id_tipo_usuario = tu.id_tipo_usuario
		WHERE s.id_seguidor = $1
		ORDER BY s.fecha_creacion DESC
	`
	rowsFollowing, err := DB.QueryContext(ctx, queryFollowing, userID, requestorID)
	if err != nil {
		return nil, fmt.Errorf("error obteniendo following: %w", err)
	}
	defer rowsFollowing.Close()

	for rowsFollowing.Next() {
		var user ConnectionUser
		var avatarURL sql.NullString
		if err := rowsFollowing.Scan(&user.UserID, &user.Username, &avatarURL, &user.Role, &user.IsFollowing); err != nil {
			return nil, err
		}
		if avatarURL.Valid {
			user.AvatarURL = avatarURL.String
		}
		resp.Following = append(resp.Following, user)
	}

	LogDB("SELECT", "seguidores_y_seguidos", time.Since(start).Milliseconds(), nil)
	return resp, nil
}

func (r *PostgresCommentRepository) CountByVideoID(ctx context.Context, videoID int) (int, error) {
	var count int
	err := DB.QueryRowContext(ctx, "SELECT COUNT(*) FROM comentarios WHERE id_contenido = $1 AND id_estado_general = $2",
		videoID, activeCommentStateID).Scan(&count)
	return count, err
}
