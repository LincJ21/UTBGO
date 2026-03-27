package main

import (
	"context"
	"time"
)

// PostgresNotificationRepository implementa NotificationRepository usando PostgreSQL.
type PostgresNotificationRepository struct{}

// NewPostgresNotificationRepository crea una nueva instancia del repositorio.
func NewPostgresNotificationRepository() *PostgresNotificationRepository {
	return &PostgresNotificationRepository{}
}

// EnsureTable crea la tabla de notificaciones si no existe.
func (r *PostgresNotificationRepository) EnsureTable(ctx context.Context) error {
	query := `
	CREATE TABLE IF NOT EXISTS notificaciones (
		id SERIAL PRIMARY KEY,
		user_id INTEGER NOT NULL,
		tipo VARCHAR(50) NOT NULL,
		titulo VARCHAR(255) NOT NULL,
		cuerpo TEXT NOT NULL,
		actor_name VARCHAR(255) DEFAULT '',
		ref_id INTEGER DEFAULT 0,
		leido BOOLEAN DEFAULT FALSE,
		created_at TIMESTAMPTZ DEFAULT NOW()
	);
	CREATE INDEX IF NOT EXISTS idx_notif_user_id ON notificaciones(user_id);
	CREATE INDEX IF NOT EXISTS idx_notif_created ON notificaciones(created_at DESC);
	`
	_, err := DB.ExecContext(ctx, query)
	if err != nil {
		Logger.Warn("Error creando tabla notificaciones", "error", err)
	} else {
		Logger.Info("Tabla notificaciones verificada/creada")
	}
	return err
}

// Create inserta una nueva notificación en la BD.
func (r *PostgresNotificationRepository) Create(ctx context.Context, n *Notification) (int, error) {
	start := time.Now()
	var id int
	err := DB.QueryRowContext(ctx,
		`INSERT INTO notificaciones (user_id, tipo, titulo, cuerpo, actor_name, ref_id)
		 VALUES ($1, $2, $3, $4, $5, $6) RETURNING id`,
		n.UserID, n.Type, n.Title, n.Body, n.ActorName, n.RefID,
	).Scan(&id)
	LogDB("INSERT", "notificaciones", time.Since(start).Milliseconds(), err)
	return id, err
}

// GetByUserID obtiene notificaciones paginadas de un usuario.
func (r *PostgresNotificationRepository) GetByUserID(ctx context.Context, userID, limit, offset int) ([]Notification, int, error) {
	start := time.Now()

	// Obtener total
	var total int
	err := DB.QueryRowContext(ctx,
		`SELECT COUNT(*) FROM notificaciones WHERE user_id = $1`, userID,
	).Scan(&total)
	if err != nil {
		LogDB("COUNT", "notificaciones", time.Since(start).Milliseconds(), err)
		return nil, 0, err
	}

	// Obtener notificaciones paginadas
	rows, err := DB.QueryContext(ctx,
		`SELECT id, user_id, tipo, titulo, cuerpo, actor_name, ref_id, leido, created_at
		 FROM notificaciones
		 WHERE user_id = $1
		 ORDER BY created_at DESC
		 LIMIT $2 OFFSET $3`,
		userID, limit, offset,
	)
	if err != nil {
		LogDB("SELECT", "notificaciones", time.Since(start).Milliseconds(), err)
		return nil, 0, err
	}
	defer rows.Close()

	var notifications []Notification
	for rows.Next() {
		var n Notification
		if err := rows.Scan(&n.ID, &n.UserID, &n.Type, &n.Title, &n.Body, &n.ActorName, &n.RefID, &n.IsRead, &n.CreatedAt); err != nil {
			return nil, 0, err
		}
		notifications = append(notifications, n)
	}

	LogDB("SELECT", "notificaciones", time.Since(start).Milliseconds(), nil)
	return notifications, total, nil
}

// MarkAsRead marca una notificación específica como leída.
func (r *PostgresNotificationRepository) MarkAsRead(ctx context.Context, notificationID, userID int) error {
	start := time.Now()
	_, err := DB.ExecContext(ctx,
		`UPDATE notificaciones SET leido = TRUE WHERE id = $1 AND user_id = $2`,
		notificationID, userID,
	)
	LogDB("UPDATE", "notificaciones", time.Since(start).Milliseconds(), err)
	return err
}

// MarkAllAsRead marca todas las notificaciones de un usuario como leídas.
func (r *PostgresNotificationRepository) MarkAllAsRead(ctx context.Context, userID int) error {
	start := time.Now()
	_, err := DB.ExecContext(ctx,
		`UPDATE notificaciones SET leido = TRUE WHERE user_id = $1 AND leido = FALSE`,
		userID,
	)
	LogDB("UPDATE_ALL", "notificaciones", time.Since(start).Milliseconds(), err)
	return err
}

// GetUnreadCount obtiene el conteo de notificaciones no leídas.
func (r *PostgresNotificationRepository) GetUnreadCount(ctx context.Context, userID int) (int, error) {
	start := time.Now()
	var count int
	err := DB.QueryRowContext(ctx,
		`SELECT COUNT(*) FROM notificaciones WHERE user_id = $1 AND leido = FALSE`,
		userID,
	).Scan(&count)
	LogDB("COUNT", "notificaciones_unread", time.Since(start).Milliseconds(), err)
	return count, err
}

// --- Función helper para generar notificaciones desde handlers ---

// CreateNotificationAsync genera una notificación de forma asíncrona (no bloquea el request).
func CreateNotificationAsync(userID int, notifType, title, body, actorName string, refID int) {
	go func() {
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()

		n := &Notification{
			UserID:    userID,
			Type:      notifType,
			Title:     title,
			Body:      body,
			ActorName: actorName,
			RefID:     refID,
		}
		_, err := Repos.Notifications.Create(ctx, n)
		if err != nil {
			Logger.Warn("Error creando notificación", "error", err, "user_id", userID, "type", notifType)
		}
	}()
}
