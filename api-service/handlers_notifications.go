package main

import (
	"math"
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"
)

// GET /api/v1/notifications
// Obtiene las notificaciones del usuario autenticado con paginación.
func handleGetNotifications(c *gin.Context) {
	userID := getUserIDFromContext(c)
	if userID == 0 {
		RespondError(c, ErrUnauthorized())
		return
	}

	page, _ := strconv.Atoi(c.DefaultQuery("page", "1"))
	pageSize, _ := strconv.Atoi(c.DefaultQuery("page_size", "20"))
	if page < 1 {
		page = 1
	}
	if pageSize < 1 || pageSize > 50 {
		pageSize = 20
	}
	offset := (page - 1) * pageSize

	notifications, total, err := Repos.Notifications.GetByUserID(c.Request.Context(), userID, pageSize, offset)
	if err != nil {
		Logger.Error("Error obteniendo notificaciones", "error", err, "user_id", userID)
		RespondError(c, ErrDatabase("Error al obtener notificaciones"))
		return
	}

	if notifications == nil {
		notifications = []Notification{}
	}

	totalPages := int(math.Ceil(float64(total) / float64(pageSize)))

	RespondSuccess(c, gin.H{
		"data": notifications,
		"pagination": gin.H{
			"total":       total,
			"page":        page,
			"page_size":   pageSize,
			"total_pages": totalPages,
		},
	})
}

// GET /api/v1/notifications/unread-count
// Obtiene el conteo de notificaciones no leídas.
func handleGetUnreadCount(c *gin.Context) {
	userID := getUserIDFromContext(c)
	if userID == 0 {
		RespondError(c, ErrUnauthorized())
		return
	}

	count, err := Repos.Notifications.GetUnreadCount(c.Request.Context(), userID)
	if err != nil {
		Logger.Error("Error obteniendo conteo de no leídas", "error", err, "user_id", userID)
		RespondError(c, ErrDatabase("Error al obtener conteo"))
		return
	}

	RespondSuccess(c, gin.H{"unread_count": count})
}

// PATCH /api/v1/notifications/:id/read
// Marca una notificación como leída.
func handleMarkNotificationRead(c *gin.Context) {
	userID := getUserIDFromContext(c)
	if userID == 0 {
		RespondError(c, ErrUnauthorized())
		return
	}

	notifID, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		RespondError(c, ErrInvalidInput("id", "ID de notificación inválido"))
		return
	}

	if err := Repos.Notifications.MarkAsRead(c.Request.Context(), notifID, userID); err != nil {
		Logger.Error("Error marcando notificación como leída", "error", err)
		RespondError(c, ErrDatabase("Error al marcar como leída"))
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Notificación marcada como leída"})
}

// PATCH /api/v1/notifications/read-all
// Marca todas las notificaciones del usuario como leídas.
func handleMarkAllNotificationsRead(c *gin.Context) {
	userID := getUserIDFromContext(c)
	if userID == 0 {
		RespondError(c, ErrUnauthorized())
		return
	}

	if err := Repos.Notifications.MarkAllAsRead(c.Request.Context(), userID); err != nil {
		Logger.Error("Error marcando todas como leídas", "error", err, "user_id", userID)
		RespondError(c, ErrDatabase("Error al marcar todas como leídas"))
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Todas las notificaciones marcadas como leídas"})
}
