package main

import (
	"context"
	"database/sql"
	"fmt"
	"math"
	"strings"
	"time"
)

// PostgresAdminRepository implementa AdminRepository usando PostgreSQL.
type PostgresAdminRepository struct{}

// NewPostgresAdminRepository crea una nueva instancia del repositorio admin.
func NewPostgresAdminRepository() *PostgresAdminRepository {
	return &PostgresAdminRepository{}
}

// --- Gestión de Usuarios ---

// GetUserAccessLevel obtiene el nivel de acceso del usuario por su ID.
// Utiliza la tabla tipos_usuario.nivel_acceso para determinar permisos.
// nivel_acceso: 1 = estudiante, 5 = moderador, 10 = administrador
func (r *PostgresAdminRepository) GetUserAccessLevel(ctx context.Context, userID int) (int, error) {
	start := time.Now()
	var accessLevel int
	err := DB.QueryRowContext(ctx, `
		SELECT tu.nivel_acceso
		FROM usuarios u
		JOIN tipos_usuario tu ON u.id_tipo_usuario = tu.id_tipo_usuario
		WHERE u.id_usuario = $1`, userID).Scan(&accessLevel)

	LogDB("SELECT", "tipos_usuario", time.Since(start).Milliseconds(), err)

	if err == sql.ErrNoRows {
		return 0, fmt.Errorf("usuario no encontrado: %d", userID)
	}
	if err != nil {
		return 0, fmt.Errorf("error obteniendo nivel de acceso: %w", err)
	}
	return accessLevel, nil
}

// ListUsers obtiene una lista paginada de usuarios con información extendida.
// Soporta búsqueda por email/nombre y filtros por rol y estado.
func (r *PostgresAdminRepository) ListUsers(ctx context.Context, page, pageSize int, search, roleFilter, statusFilter string) ([]AdminUser, int, error) {
	start := time.Now()

	// Construir cláusulas WHERE dinámicas
	conditions := []string{"1=1"}
	args := []interface{}{}
	argIdx := 1

	if search != "" {
		conditions = append(conditions, fmt.Sprintf(
			"(LOWER(u.email) LIKE $%d OR LOWER(p.nombre) LIKE $%d OR LOWER(p.apellido) LIKE $%d)", argIdx, argIdx, argIdx))
		args = append(args, "%"+strings.ToLower(search)+"%")
		argIdx++
	}
	if roleFilter != "" {
		conditions = append(conditions, fmt.Sprintf("tu.codigo = $%d", argIdx))
		args = append(args, roleFilter)
		argIdx++
	}
	if statusFilter != "" {
		conditions = append(conditions, fmt.Sprintf("eu.codigo = $%d", argIdx))
		args = append(args, statusFilter)
		argIdx++
	}

	whereClause := strings.Join(conditions, " AND ")

	// Contar total (para paginación)
	countQuery := fmt.Sprintf(`
		SELECT COUNT(*)
		FROM usuarios u
		JOIN tipos_usuario tu ON u.id_tipo_usuario = tu.id_tipo_usuario
		JOIN estados_usuario eu ON u.id_estado_usuario = eu.id_estado_usuario
		LEFT JOIN perfiles p ON u.id_usuario = p.id_usuario
		WHERE %s`, whereClause)

	var total int
	err := DB.QueryRowContext(ctx, countQuery, args...).Scan(&total)
	if err != nil {
		LogDB("COUNT", "usuarios", time.Since(start).Milliseconds(), err)
		return nil, 0, fmt.Errorf("error contando usuarios: %w", err)
	}

	// Obtener datos paginados
	offset := (page - 1) * pageSize
	dataArgs := append(args, pageSize, offset)

	dataQuery := fmt.Sprintf(`
		SELECT 
			u.id_usuario, u.email,
			COALESCE(p.nombre, ''), COALESCE(p.apellido, ''), COALESCE(p.avatar_url, ''),
			tu.codigo, tu.nombre, tu.nivel_acceso,
			eu.codigo, eu.nombre,
			u.fecha_registro, COALESCE(u.ultimo_login, u.fecha_registro),
			(SELECT COUNT(*) FROM contenidos c WHERE c.id_autor = u.id_usuario) as videos_count,
			(SELECT COUNT(*) FROM comentarios co WHERE co.id_usuario = u.id_usuario) as comments_count
		FROM usuarios u
		JOIN tipos_usuario tu ON u.id_tipo_usuario = tu.id_tipo_usuario
		JOIN estados_usuario eu ON u.id_estado_usuario = eu.id_estado_usuario
		LEFT JOIN perfiles p ON u.id_usuario = p.id_usuario
		WHERE %s
		ORDER BY u.fecha_registro DESC
		LIMIT $%d OFFSET $%d`, whereClause, argIdx, argIdx+1)

	rows, err := DB.QueryContext(ctx, dataQuery, dataArgs...)
	LogDB("SELECT", "usuarios (admin list)", time.Since(start).Milliseconds(), err)
	if err != nil {
		return nil, 0, fmt.Errorf("error listando usuarios: %w", err)
	}
	defer rows.Close()

	var users []AdminUser
	for rows.Next() {
		var u AdminUser
		if err := rows.Scan(
			&u.ID, &u.Email, &u.Name, &u.LastName, &u.AvatarURL,
			&u.RoleCode, &u.RoleName, &u.AccessLevel,
			&u.StatusCode, &u.StatusName,
			&u.CreatedAt, &u.LastLogin,
			&u.VideosCount, &u.CommentsCount,
		); err != nil {
			Logger.Warn("Error escaneando usuario admin", "error", err)
			continue
		}
		users = append(users, u)
	}
	if err := rows.Err(); err != nil {
		return nil, 0, fmt.Errorf("error iterando usuarios: %w", err)
	}

	return users, total, nil
}

// GetUserByID obtiene información completa de un usuario para el admin.
func (r *PostgresAdminRepository) GetUserByID(ctx context.Context, userID int) (*AdminUser, error) {
	start := time.Now()
	var u AdminUser

	err := DB.QueryRowContext(ctx, `
		SELECT 
			u.id_usuario, u.email,
			COALESCE(p.nombre, ''), COALESCE(p.apellido, ''), COALESCE(p.avatar_url, ''),
			tu.codigo, tu.nombre, tu.nivel_acceso,
			eu.codigo, eu.nombre,
			u.fecha_registro, COALESCE(u.ultimo_login, u.fecha_registro),
			(SELECT COUNT(*) FROM contenidos c WHERE c.id_autor = u.id_usuario) as videos_count,
			(SELECT COUNT(*) FROM comentarios co WHERE co.id_usuario = u.id_usuario) as comments_count
		FROM usuarios u
		JOIN tipos_usuario tu ON u.id_tipo_usuario = tu.id_tipo_usuario
		JOIN estados_usuario eu ON u.id_estado_usuario = eu.id_estado_usuario
		LEFT JOIN perfiles p ON u.id_usuario = p.id_usuario
		WHERE u.id_usuario = $1`, userID).Scan(
		&u.ID, &u.Email, &u.Name, &u.LastName, &u.AvatarURL,
		&u.RoleCode, &u.RoleName, &u.AccessLevel,
		&u.StatusCode, &u.StatusName,
		&u.CreatedAt, &u.LastLogin,
		&u.VideosCount, &u.CommentsCount,
	)

	LogDB("SELECT", "usuarios (admin detail)", time.Since(start).Milliseconds(), err)

	if err == sql.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, fmt.Errorf("error obteniendo usuario: %w", err)
	}
	return &u, nil
}

// UpdateUserStatus cambia el estado de un usuario (activo, suspendido, baneado).
func (r *PostgresAdminRepository) UpdateUserStatus(ctx context.Context, userID int, statusCode string) error {
	start := time.Now()

	// Validar que el estado existe
	var statusID int
	err := DB.QueryRowContext(ctx,
		"SELECT id_estado_usuario FROM estados_usuario WHERE codigo = $1", statusCode).Scan(&statusID)
	if err == sql.ErrNoRows {
		return fmt.Errorf("estado de usuario inválido: %s", statusCode)
	}
	if err != nil {
		return fmt.Errorf("error buscando estado: %w", err)
	}

	// Actualizar el estado del usuario
	result, err := DB.ExecContext(ctx,
		"UPDATE usuarios SET id_estado_usuario = $1 WHERE id_usuario = $2", statusID, userID)
	LogDB("UPDATE", "usuarios (status)", time.Since(start).Milliseconds(), err)
	if err != nil {
		return fmt.Errorf("error actualizando estado: %w", err)
	}

	rows, _ := result.RowsAffected()
	if rows == 0 {
		return fmt.Errorf("usuario no encontrado: %d", userID)
	}

	Logger.Info("Estado de usuario actualizado por admin",
		"user_id", userID, "new_status", statusCode)
	return nil
}

// UpdateUserRole cambia el rol de un usuario (estudiante, moderador, admin).
func (r *PostgresAdminRepository) UpdateUserRole(ctx context.Context, userID int, roleCode string) error {
	start := time.Now()

	// Validar que el rol existe
	var roleID int
	err := DB.QueryRowContext(ctx,
		"SELECT id_tipo_usuario FROM tipos_usuario WHERE codigo = $1", roleCode).Scan(&roleID)
	if err == sql.ErrNoRows {
		return fmt.Errorf("rol de usuario inválido: %s", roleCode)
	}
	if err != nil {
		return fmt.Errorf("error buscando rol: %w", err)
	}

	// Actualizar el rol del usuario
	result, err := DB.ExecContext(ctx,
		"UPDATE usuarios SET id_tipo_usuario = $1 WHERE id_usuario = $2", roleID, userID)
	LogDB("UPDATE", "usuarios (role)", time.Since(start).Milliseconds(), err)
	if err != nil {
		return fmt.Errorf("error actualizando rol: %w", err)
	}

	rows, _ := result.RowsAffected()
	if rows == 0 {
		return fmt.Errorf("usuario no encontrado: %d", userID)
	}

	Logger.Info("Rol de usuario actualizado por admin",
		"user_id", userID, "new_role", roleCode)
	return nil
}

// --- Moderación de Contenido ---

// ListVideos obtiene videos paginados con información extendida para moderación.
func (r *PostgresAdminRepository) ListVideos(ctx context.Context, page, pageSize int, search, statusFilter string) ([]AdminVideo, int, error) {
	start := time.Now()

	conditions := []string{"1=1"}
	args := []interface{}{}
	argIdx := 1

	if search != "" {
		conditions = append(conditions, fmt.Sprintf(
			"(LOWER(c.titulo) LIKE $%d OR LOWER(c.descripcion) LIKE $%d)", argIdx, argIdx))
		args = append(args, "%"+strings.ToLower(search)+"%")
		argIdx++
	}
	if statusFilter != "" {
		conditions = append(conditions, fmt.Sprintf("ec.codigo = $%d", argIdx))
		args = append(args, statusFilter)
		argIdx++
	}

	whereClause := strings.Join(conditions, " AND ")

	// Contar total
	countQuery := fmt.Sprintf(`
		SELECT COUNT(*)
		FROM contenidos c
		JOIN estados_contenido ec ON c.id_estado_contenido = ec.id_estado_contenido
		WHERE %s`, whereClause)

	var total int
	err := DB.QueryRowContext(ctx, countQuery, args...).Scan(&total)
	if err != nil {
		LogDB("COUNT", "contenidos (admin)", time.Since(start).Milliseconds(), err)
		return nil, 0, fmt.Errorf("error contando videos: %w", err)
	}

	// Datos paginados
	offset := (page - 1) * pageSize
	dataArgs := append(args, pageSize, offset)

	dataQuery := fmt.Sprintf(`
		SELECT 
			c.id_contenido, c.titulo, COALESCE(c.descripcion, ''),
			c.url_contenido, COALESCE(c.url_thumbnail, ''),
			c.id_autor, COALESCE(p.nombre || ' ' || p.apellido, u.email), u.email,
			ec.codigo, ec.nombre,
			(SELECT COUNT(*) FROM interacciones i WHERE i.id_contenido = c.id_contenido AND i.id_tipo_interaccion = %d) as likes_count,
			(SELECT COUNT(*) FROM comentarios co WHERE co.id_contenido = c.id_contenido) as comments_count,
			c.fecha_creacion
		FROM contenidos c
		JOIN usuarios u ON c.id_autor = u.id_usuario
		JOIN estados_contenido ec ON c.id_estado_contenido = ec.id_estado_contenido
		LEFT JOIN perfiles p ON c.id_autor = p.id_usuario
		WHERE %s
		ORDER BY c.fecha_creacion DESC
		LIMIT $%d OFFSET $%d`, likeInteractionTypeID, whereClause, argIdx, argIdx+1)

	rows, err := DB.QueryContext(ctx, dataQuery, dataArgs...)
	LogDB("SELECT", "contenidos (admin list)", time.Since(start).Milliseconds(), err)
	if err != nil {
		return nil, 0, fmt.Errorf("error listando videos: %w", err)
	}
	defer rows.Close()

	var videos []AdminVideo
	for rows.Next() {
		var v AdminVideo
		if err := rows.Scan(
			&v.ID, &v.Title, &v.Description,
			&v.VideoURL, &v.ThumbnailURL,
			&v.AuthorID, &v.AuthorName, &v.AuthorEmail,
			&v.StatusCode, &v.StatusName,
			&v.LikesCount, &v.CommentsCount,
			&v.CreatedAt,
		); err != nil {
			Logger.Warn("Error escaneando video admin", "error", err)
			continue
		}
		videos = append(videos, v)
	}
	if err := rows.Err(); err != nil {
		return nil, 0, fmt.Errorf("error iterando videos: %w", err)
	}

	return videos, total, nil
}

// UpdateVideoStatus cambia el estado de un video (publicado, eliminado, oculto).
func (r *PostgresAdminRepository) UpdateVideoStatus(ctx context.Context, videoID int, statusCode string) error {
	start := time.Now()

	var statusID int
	err := DB.QueryRowContext(ctx,
		"SELECT id_estado_contenido FROM estados_contenido WHERE codigo = $1", statusCode).Scan(&statusID)
	if err == sql.ErrNoRows {
		return fmt.Errorf("estado de contenido inválido: %s", statusCode)
	}
	if err != nil {
		return fmt.Errorf("error buscando estado de contenido: %w", err)
	}

	result, err := DB.ExecContext(ctx,
		"UPDATE contenidos SET id_estado_contenido = $1 WHERE id_contenido = $2", statusID, videoID)
	LogDB("UPDATE", "contenidos (admin status)", time.Since(start).Milliseconds(), err)
	if err != nil {
		return fmt.Errorf("error actualizando estado de video: %w", err)
	}

	rows, _ := result.RowsAffected()
	if rows == 0 {
		return fmt.Errorf("video no encontrado: %d", videoID)
	}

	Logger.Info("Estado de video actualizado por admin",
		"video_id", videoID, "new_status", statusCode)
	return nil
}

// DeleteVideo elimina permanentemente un video y sus datos relacionados.
func (r *PostgresAdminRepository) DeleteVideo(ctx context.Context, videoID int) error {
	start := time.Now()

	// Eliminar en orden: comentarios → interacciones → favoritos → contenido
	tx, err := DB.BeginTx(ctx, nil)
	if err != nil {
		return fmt.Errorf("error iniciando transacción: %w", err)
	}
	defer tx.Rollback()

	// Eliminar comentarios del video
	_, err = tx.ExecContext(ctx, "DELETE FROM comentarios WHERE id_contenido = $1", videoID)
	if err != nil {
		return fmt.Errorf("error eliminando comentarios: %w", err)
	}

	// Eliminar interacciones (likes)
	_, err = tx.ExecContext(ctx, "DELETE FROM interacciones WHERE id_contenido = $1", videoID)
	if err != nil {
		return fmt.Errorf("error eliminando interacciones: %w", err)
	}

	// Eliminar favoritos
	_, err = tx.ExecContext(ctx, "DELETE FROM favoritos WHERE id_contenido = $1", videoID)
	if err != nil {
		return fmt.Errorf("error eliminando favoritos: %w", err)
	}

	// Eliminar el video
	result, err := tx.ExecContext(ctx, "DELETE FROM contenidos WHERE id_contenido = $1", videoID)
	if err != nil {
		return fmt.Errorf("error eliminando video: %w", err)
	}

	rows, _ := result.RowsAffected()
	if rows == 0 {
		return fmt.Errorf("video no encontrado: %d", videoID)
	}

	if err := tx.Commit(); err != nil {
		return fmt.Errorf("error confirmando transacción: %w", err)
	}

	LogDB("DELETE", "contenidos (admin hard delete)", time.Since(start).Milliseconds(), nil)
	Logger.Info("Video eliminado permanentemente por admin", "video_id", videoID)
	return nil
}

// ListComments obtiene comentarios paginados para moderación.
func (r *PostgresAdminRepository) ListComments(ctx context.Context, page, pageSize int, search string) ([]AdminComment, int, error) {
	start := time.Now()

	conditions := []string{"1=1"}
	args := []interface{}{}
	argIdx := 1

	if search != "" {
		conditions = append(conditions, fmt.Sprintf("LOWER(co.texto) LIKE $%d", argIdx))
		args = append(args, "%"+strings.ToLower(search)+"%")
		argIdx++
	}

	whereClause := strings.Join(conditions, " AND ")

	// Contar total
	countQuery := fmt.Sprintf(`SELECT COUNT(*) FROM comentarios co WHERE %s`, whereClause)
	var total int
	err := DB.QueryRowContext(ctx, countQuery, args...).Scan(&total)
	if err != nil {
		LogDB("COUNT", "comentarios (admin)", time.Since(start).Milliseconds(), err)
		return nil, 0, fmt.Errorf("error contando comentarios: %w", err)
	}

	// Datos paginados
	offset := (page - 1) * pageSize
	dataArgs := append(args, pageSize, offset)

	dataQuery := fmt.Sprintf(`
		SELECT 
			co.id_comentario, co.texto,
			co.id_usuario, COALESCE(p.nombre || ' ' || p.apellido, u.email), u.email,
			co.id_contenido, COALESCE(c.titulo, 'Sin título'),
			COALESCE(eg.codigo, 'activo'),
			co.fecha_creacion
		FROM comentarios co
		JOIN usuarios u ON co.id_usuario = u.id_usuario
		LEFT JOIN perfiles p ON co.id_usuario = p.id_usuario
		LEFT JOIN contenidos c ON co.id_contenido = c.id_contenido
		LEFT JOIN estados_general eg ON co.id_estado_general = eg.id_estado_general
		WHERE %s
		ORDER BY co.fecha_creacion DESC
		LIMIT $%d OFFSET $%d`, whereClause, argIdx, argIdx+1)

	rows, err := DB.QueryContext(ctx, dataQuery, dataArgs...)
	LogDB("SELECT", "comentarios (admin list)", time.Since(start).Milliseconds(), err)
	if err != nil {
		return nil, 0, fmt.Errorf("error listando comentarios: %w", err)
	}
	defer rows.Close()

	var comments []AdminComment
	for rows.Next() {
		var c AdminComment
		if err := rows.Scan(
			&c.ID, &c.Text,
			&c.UserID, &c.Username, &c.UserEmail,
			&c.VideoID, &c.VideoTitle,
			&c.StatusCode,
			&c.CreatedAt,
		); err != nil {
			Logger.Warn("Error escaneando comentario admin", "error", err)
			continue
		}
		comments = append(comments, c)
	}
	if err := rows.Err(); err != nil {
		return nil, 0, fmt.Errorf("error iterando comentarios: %w", err)
	}

	return comments, total, nil
}

// DeleteComment elimina un comentario por un administrador (sin verificar autoría).
func (r *PostgresAdminRepository) DeleteComment(ctx context.Context, commentID int) error {
	start := time.Now()

	result, err := DB.ExecContext(ctx, "DELETE FROM comentarios WHERE id_comentario = $1", commentID)
	LogDB("DELETE", "comentarios (admin)", time.Since(start).Milliseconds(), err)
	if err != nil {
		return fmt.Errorf("error eliminando comentario: %w", err)
	}

	rows, _ := result.RowsAffected()
	if rows == 0 {
		return fmt.Errorf("comentario no encontrado: %d", commentID)
	}

	Logger.Info("Comentario eliminado por admin", "comment_id", commentID)
	return nil
}

// --- Estadísticas ---

// GetDashboardStats obtiene estadísticas globales del dashboard de administración.
func (r *PostgresAdminRepository) GetDashboardStats(ctx context.Context) (*AdminStats, error) {
	start := time.Now()
	stats := &AdminStats{}

	// Total usuarios
	DB.QueryRowContext(ctx, "SELECT COUNT(*) FROM usuarios").Scan(&stats.TotalUsers)

	// Usuarios activos y baneados
	DB.QueryRowContext(ctx, `
		SELECT COUNT(*) FROM usuarios u 
		JOIN estados_usuario eu ON u.id_estado_usuario = eu.id_estado_usuario 
		WHERE eu.codigo = 'activo'`).Scan(&stats.ActiveUsers)

	DB.QueryRowContext(ctx, `
		SELECT COUNT(*) FROM usuarios u 
		JOIN estados_usuario eu ON u.id_estado_usuario = eu.id_estado_usuario 
		WHERE eu.codigo IN ('suspendido', 'baneado')`).Scan(&stats.BannedUsers)

	// Total videos
	DB.QueryRowContext(ctx, "SELECT COUNT(*) FROM contenidos").Scan(&stats.TotalVideos)

	// Videos publicados
	DB.QueryRowContext(ctx, `
		SELECT COUNT(*) FROM contenidos c 
		JOIN estados_contenido ec ON c.id_estado_contenido = ec.id_estado_contenido 
		WHERE ec.codigo = 'publicado'`).Scan(&stats.PublishedVideos)

	// Videos eliminados/ocultos
	DB.QueryRowContext(ctx, `
		SELECT COUNT(*) FROM contenidos c 
		JOIN estados_contenido ec ON c.id_estado_contenido = ec.id_estado_contenido 
		WHERE ec.codigo IN ('eliminado', 'oculto')`).Scan(&stats.RemovedVideos)

	// Total comentarios
	DB.QueryRowContext(ctx, "SELECT COUNT(*) FROM comentarios").Scan(&stats.TotalComments)

	// Total likes
	DB.QueryRowContext(ctx, `
		SELECT COUNT(*) FROM interacciones 
		WHERE id_tipo_interaccion = $1`, likeInteractionTypeID).Scan(&stats.TotalLikes)

	// Registros recientes (últimos 7 días)
	DB.QueryRowContext(ctx, `
		SELECT COUNT(*) FROM usuarios 
		WHERE fecha_registro >= NOW() - INTERVAL '7 days'`).Scan(&stats.RecentSignups)

	// Distribución de roles
	rows, err := DB.QueryContext(ctx, `
		SELECT tu.codigo, tu.nombre, COUNT(u.id_usuario) as count
		FROM tipos_usuario tu
		LEFT JOIN usuarios u ON tu.id_tipo_usuario = u.id_tipo_usuario
		GROUP BY tu.codigo, tu.nombre
		ORDER BY count DESC`)
	if err == nil {
		defer rows.Close()
		for rows.Next() {
			var rc RoleCount
			if err := rows.Scan(&rc.RoleCode, &rc.RoleName, &rc.Count); err == nil {
				stats.TopRoles = append(stats.TopRoles, rc)
			}
		}
	}

	LogDB("STATS", "dashboard", time.Since(start).Milliseconds(), nil)
	return stats, nil
}

// --- Gestión de Roles ---

// EnsureAdminRole verifica que los roles admin y moderador existan en la BD.
// Si no existen, los crea. Esto es un "self-healing" para la inicialización.
func (r *PostgresAdminRepository) EnsureAdminRole(ctx context.Context) error {
	roles := []struct {
		codigo      string
		nombre      string
		descripcion string
		nivelAcceso int
	}{
		{"moderador", "Moderador", "Puede moderar contenido y usuarios", 5},
		{"admin", "Administrador", "Acceso total al sistema", 10},
	}

	for _, role := range roles {
		var exists bool
		err := DB.QueryRowContext(ctx,
			"SELECT EXISTS(SELECT 1 FROM tipos_usuario WHERE codigo = $1)", role.codigo).Scan(&exists)
		if err != nil {
			return fmt.Errorf("error verificando rol '%s': %w", role.codigo, err)
		}
		if !exists {
			_, err = DB.ExecContext(ctx, `
				INSERT INTO tipos_usuario (codigo, nombre, descripcion, nivel_acceso)
				VALUES ($1, $2, $3, $4)`,
				role.codigo, role.nombre, role.descripcion, role.nivelAcceso)
			if err != nil {
				return fmt.Errorf("error creando rol '%s': %w", role.codigo, err)
			}
			Logger.Info("Rol creado en la BD", "codigo", role.codigo, "nivel_acceso", role.nivelAcceso)
		}
	}

	// Verificar que existan los estados necesarios para moderación
	statuses := []struct {
		codigo      string
		nombre      string
		descripcion string
	}{
		{"suspendido", "Suspendido", "Usuario suspendido temporalmente"},
		{"baneado", "Baneado", "Usuario baneado permanentemente"},
	}

	for _, status := range statuses {
		var exists bool
		err := DB.QueryRowContext(ctx,
			"SELECT EXISTS(SELECT 1 FROM estados_usuario WHERE codigo = $1)", status.codigo).Scan(&exists)
		if err != nil {
			return fmt.Errorf("error verificando estado '%s': %w", status.codigo, err)
		}
		if !exists {
			_, err = DB.ExecContext(ctx, `
				INSERT INTO estados_usuario (codigo, nombre, descripcion)
				VALUES ($1, $2, $3)`,
				status.codigo, status.nombre, status.descripcion)
			if err != nil {
				return fmt.Errorf("error creando estado '%s': %w", status.codigo, err)
			}
			Logger.Info("Estado de usuario creado en la BD", "codigo", status.codigo)
		}
	}

	// Verificar estados de contenido para moderación
	contentStatuses := []struct {
		codigo      string
		nombre      string
		descripcion string
	}{
		{"oculto", "Oculto", "Contenido oculto por moderación"},
		{"eliminado", "Eliminado", "Contenido eliminado por administrador"},
	}

	for _, cs := range contentStatuses {
		var exists bool
		err := DB.QueryRowContext(ctx,
			"SELECT EXISTS(SELECT 1 FROM estados_contenido WHERE codigo = $1)", cs.codigo).Scan(&exists)
		if err != nil {
			return fmt.Errorf("error verificando estado de contenido '%s': %w", cs.codigo, err)
		}
		if !exists {
			_, err = DB.ExecContext(ctx, `
				INSERT INTO estados_contenido (codigo, nombre, descripcion)
				VALUES ($1, $2, $3)`,
				cs.codigo, cs.nombre, cs.descripcion)
			if err != nil {
				return fmt.Errorf("error creando estado de contenido '%s': %w", cs.codigo, err)
			}
			Logger.Info("Estado de contenido creado en la BD", "codigo", cs.codigo)
		}
	}

	return nil
}

// --- Helpers ---

// CalculateTotalPages calcula el número total de páginas para paginación.
func CalculateTotalPages(total, pageSize int) int {
	if pageSize <= 0 {
		return 0
	}
	return int(math.Ceil(float64(total) / float64(pageSize)))
}
