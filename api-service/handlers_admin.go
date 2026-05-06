package main

import (
	"context"
	"fmt"
	"net/http"
	"strconv"
	"time"

	"github.com/gin-gonic/gin"
)

// ============================================================================
// HANDLERS DE ADMINISTRACIÓN — Servicio de Administración de UTBGO
// ============================================================================
//
// Todos los handlers requieren autenticación (AuthMiddleware) y permisos
// de admin/moderador (AdminMiddleware). Las rutas se registran en main.go
// bajo /api/v1/admin/*.
//
// Niveles de acceso:
//   - Moderador (5): Puede listar/moderar contenido y usuarios
//   - Admin (10): Todo lo anterior + cambiar roles + eliminar permanentemente
//
// Convenciones:
//   - Paginación: ?page=1&page_size=20
//   - Búsqueda: ?search=texto
//   - Filtros: ?role=admin&status=activo (según endpoint)
//   - Respuestas: JSON con estructura consistente
// ============================================================================

// --- Dashboard ---

// handleAdminDashboard devuelve estadísticas globales del sistema.
// GET /api/v1/admin/dashboard
// Requiere: Moderador (5+)
func handleAdminDashboard(c *gin.Context) {
	ctx, cancel := context.WithTimeout(c.Request.Context(), 10*time.Second)
	defer cancel()

	stats, err := Repos.Admin.GetDashboardStats(ctx)
	if err != nil {
		Logger.Error("Error obteniendo estadísticas del dashboard", "error", err)
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "Error obteniendo estadísticas",
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"data":    stats,
	})
}

// --- Gestión de Usuarios ---

// handleAdminListUsers lista usuarios con paginación, búsqueda y filtros.
// GET /api/v1/admin/users?page=1&page_size=20&search=texto&role=admin&status=activo
// Requiere: Moderador (5+)
func handleAdminListUsers(c *gin.Context) {
	page, pageSize := parsePagination(c)
	search := c.Query("search")
	roleFilter := c.Query("role")
	statusFilter := c.Query("status")

	ctx, cancel := context.WithTimeout(c.Request.Context(), 10*time.Second)
	defer cancel()

	users, total, err := Repos.Admin.ListUsers(ctx, page, pageSize, search, roleFilter, statusFilter)
	if err != nil {
		Logger.Error("Error listando usuarios", "error", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Error listando usuarios"})
		return
	}

	if users == nil {
		users = []AdminUser{}
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"data":    users,
		"pagination": gin.H{
			"total":       total,
			"page":        page,
			"page_size":   pageSize,
			"total_pages": CalculateTotalPages(total, pageSize),
		},
	})
}

// handleAdminGetUser obtiene información detallada de un usuario específico.
// GET /api/v1/admin/users/:id
// Requiere: Moderador (5+)
func handleAdminGetUser(c *gin.Context) {
	userID, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "ID de usuario inválido"})
		return
	}

	ctx, cancel := context.WithTimeout(c.Request.Context(), 5*time.Second)
	defer cancel()

	user, err := Repos.Admin.GetUserByID(ctx, userID)
	if err != nil {
		Logger.Error("Error obteniendo usuario", "user_id", userID, "error", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Error obteniendo usuario"})
		return
	}
	if user == nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Usuario no encontrado"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"data":    user,
	})
}

// handleAdminUpdateUserStatus cambia el estado de un usuario.
// PATCH /api/v1/admin/users/:id/status
// Body: { "status": "activo" | "suspendido" | "baneado" }
// Requiere: Moderador (5+)
func handleAdminUpdateUserStatus(c *gin.Context) {
	userID, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "ID de usuario inválido"})
		return
	}

	var body struct {
		Status string `json:"status" binding:"required"`
	}
	if err := c.ShouldBindJSON(&body); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Campo 'status' requerido (activo, suspendido, baneado)"})
		return
	}

	// Validar valores permitidos
	validStatuses := map[string]bool{
		"activo":     true,
		"suspendido": true,
		"baneado":    true,
	}
	if !validStatuses[body.Status] {
		c.JSON(http.StatusBadRequest, gin.H{
			"error":           "Estado inválido",
			"valid_statuses":  []string{"activo", "suspendido", "baneado"},
		})
		return
	}

	// Prevenir que un admin se banee a sí mismo
	adminID := int(c.GetFloat64("userID"))
	if adminID == userID && (body.Status == "suspendido" || body.Status == "baneado") {
		c.JSON(http.StatusBadRequest, gin.H{"error": "No puedes suspender/banear tu propia cuenta"})
		return
	}

	ctx, cancel := context.WithTimeout(c.Request.Context(), 5*time.Second)
	defer cancel()

	// Verificar que no se esté cambiando el estado de un admin superior
	targetUser, err := Repos.Admin.GetUserByID(ctx, userID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Error verificando usuario"})
		return
	}
	if targetUser == nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Usuario no encontrado"})
		return
	}

	adminLevel := c.GetInt("accessLevel")
	if targetUser.AccessLevel >= adminLevel {
		c.JSON(http.StatusForbidden, gin.H{
			"error": "No puedes modificar a un usuario con igual o mayor nivel de acceso",
		})
		return
	}

	if err := Repos.Admin.UpdateUserStatus(ctx, userID, body.Status); err != nil {
		Logger.Error("Error actualizando estado de usuario",
			"user_id", userID, "status", body.Status, "error", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Error actualizando estado"})
		return
	}

	// Invalidar caché del perfil si Redis está disponible
	if Cache != nil {
		Cache.InvalidateProfile(ctx, userID)
	}

	Logger.Info("Admin actualizó estado de usuario",
		"admin_id", adminID, "target_user_id", userID, "new_status", body.Status)

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"message": "Estado del usuario actualizado correctamente",
		"data": gin.H{
			"user_id":    userID,
			"new_status": body.Status,
		},
	})
}

// handleAdminUpdateUserRole cambia el rol de un usuario.
// PATCH /api/v1/admin/users/:id/role
// Body: { "role": "estudiante" | "moderador" | "admin" }
// Requiere: Admin (10)
func handleAdminUpdateUserRole(c *gin.Context) {
	userID, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "ID de usuario inválido"})
		return
	}

	var body struct {
		Role string `json:"role" binding:"required"`
	}
	if err := c.ShouldBindJSON(&body); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Campo 'role' requerido (estudiante, moderador, admin)"})
		return
	}

	validRoles := map[string]bool{
		"estudiante": true,
		"moderador":  true,
		"admin":      true,
	}
	if !validRoles[body.Role] {
		c.JSON(http.StatusBadRequest, gin.H{
			"error":       "Rol inválido",
			"valid_roles": []string{"estudiante", "moderador", "admin"},
		})
		return
	}

	// Prevenir que un admin se degrade a sí mismo
	adminID := int(c.GetFloat64("userID"))
	if adminID == userID {
		c.JSON(http.StatusBadRequest, gin.H{"error": "No puedes cambiar tu propio rol"})
		return
	}

	ctx, cancel := context.WithTimeout(c.Request.Context(), 5*time.Second)
	defer cancel()

	if err := Repos.Admin.UpdateUserRole(ctx, userID, body.Role); err != nil {
		Logger.Error("Error actualizando rol de usuario",
			"user_id", userID, "role", body.Role, "error", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Error actualizando rol"})
		return
	}

	Logger.Info("Admin actualizó rol de usuario",
		"admin_id", adminID, "target_user_id", userID, "new_role", body.Role)

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"message": "Rol del usuario actualizado correctamente",
		"data": gin.H{
			"user_id":  userID,
			"new_role": body.Role,
		},
	})
}

// --- Moderación de Videos ---

// handleAdminListVideos lista videos con paginación, búsqueda y filtro de estado.
// GET /api/v1/admin/videos?page=1&page_size=20&search=texto&status=publicado
// Requiere: Moderador (5+)
func handleAdminListVideos(c *gin.Context) {
	page, pageSize := parsePagination(c)
	search := c.Query("search")
	statusFilter := c.Query("status")

	ctx, cancel := context.WithTimeout(c.Request.Context(), 10*time.Second)
	defer cancel()

	videos, total, err := Repos.Admin.ListVideos(ctx, page, pageSize, search, statusFilter)
	if err != nil {
		Logger.Error("Error listando videos", "error", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Error listando videos"})
		return
	}

	if videos == nil {
		videos = []AdminVideo{}
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"data":    videos,
		"pagination": gin.H{
			"total":       total,
			"page":        page,
			"page_size":   pageSize,
			"total_pages": CalculateTotalPages(total, pageSize),
		},
	})
}

// handleAdminUpdateVideoStatus cambia el estado de un video.
// PATCH /api/v1/admin/videos/:id/status
// Body: { "status": "publicado" | "oculto" | "eliminado" }
// Requiere: Moderador (5+)
func handleAdminUpdateVideoStatus(c *gin.Context) {
	videoID, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "ID de video inválido"})
		return
	}

	var body struct {
		Status string `json:"status" binding:"required"`
	}
	if err := c.ShouldBindJSON(&body); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Campo 'status' requerido (publicado, oculto, eliminado)"})
		return
	}

	validStatuses := map[string]bool{
		"publicado": true,
		"oculto":    true,
		"eliminado": true,
	}
	if !validStatuses[body.Status] {
		c.JSON(http.StatusBadRequest, gin.H{
			"error":           "Estado inválido",
			"valid_statuses":  []string{"publicado", "oculto", "eliminado"},
		})
		return
	}

	ctx, cancel := context.WithTimeout(c.Request.Context(), 5*time.Second)
	defer cancel()

	if err := Repos.Admin.UpdateVideoStatus(ctx, videoID, body.Status); err != nil {
		Logger.Error("Error actualizando estado de video",
			"video_id", videoID, "status", body.Status, "error", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Error actualizando estado del video"})
		return
	}

	// Invalidar caché del feed
	if Cache != nil {
		Cache.InvalidateFeed(ctx)
	}

	adminID := int(c.GetFloat64("userID"))
	Logger.Info("Admin actualizó estado de video",
		"admin_id", adminID, "video_id", videoID, "new_status", body.Status)

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"message": "Estado del video actualizado correctamente",
		"data": gin.H{
			"video_id":   videoID,
			"new_status": body.Status,
		},
	})
}

// handleAdminDeleteVideo elimina permanentemente un video y sus datos relacionados.
// DELETE /api/v1/admin/videos/:id
// Requiere: Admin (10)
func handleAdminDeleteVideo(c *gin.Context) {
	videoID, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "ID de video inválido"})
		return
	}

	ctx, cancel := context.WithTimeout(c.Request.Context(), 10*time.Second)
	defer cancel()

	if err := Repos.Admin.DeleteVideo(ctx, videoID); err != nil {
		Logger.Error("Error eliminando video permanentemente",
			"video_id", videoID, "error", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Error eliminando video"})
		return
	}

	// Invalidar caché del feed
	if Cache != nil {
		Cache.InvalidateFeed(ctx)
	}

	adminID := int(c.GetFloat64("userID"))
	Logger.Info("Admin eliminó video permanentemente",
		"admin_id", adminID, "video_id", videoID)

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"message": "Video eliminado permanentemente",
	})
}

// --- Moderación de Comentarios ---

// handleAdminListComments lista comentarios con paginación y búsqueda.
// GET /api/v1/admin/comments?page=1&page_size=20&search=texto
// Requiere: Moderador (5+)
func handleAdminListComments(c *gin.Context) {
	page, pageSize := parsePagination(c)
	search := c.Query("search")

	ctx, cancel := context.WithTimeout(c.Request.Context(), 10*time.Second)
	defer cancel()

	comments, total, err := Repos.Admin.ListComments(ctx, page, pageSize, search)
	if err != nil {
		Logger.Error("Error listando comentarios", "error", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Error listando comentarios"})
		return
	}

	if comments == nil {
		comments = []AdminComment{}
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"data":    comments,
		"pagination": gin.H{
			"total":       total,
			"page":        page,
			"page_size":   pageSize,
			"total_pages": CalculateTotalPages(total, pageSize),
		},
	})
}

// handleGetReports devuelve los reportes pendientes.
func handleGetReports(c *gin.Context) {
	page, _ := strconv.Atoi(c.DefaultQuery("page", "1"))
	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "20"))

	ctx := context.Background()
	reports, total, err := Repos.Admin.GetPendingReports(ctx, page, limit)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Error al obtener reportes"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"data": reports,
		"meta": gin.H{
			"total": total,
			"page":  page,
			"limit": limit,
		},
	})
}

// handleResolveReport permite al admin ignorar un reporte o borrar el comentario.
func handleResolveReport(c *gin.Context) {
	reportID, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "ID inválido"})
		return
	}

	var req struct {
		Action string `json:"action" binding:"required,oneof=ignore delete"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Acción inválida. Debe ser 'ignore' o 'delete'"})
		return
	}

	ctx := context.Background()
	videoID, err := Repos.Admin.ResolveReport(ctx, reportID, req.Action)
	if err != nil {
		Logger.Error("Error resolviendo reporte", "error", err, "report_id", reportID)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Error al procesar el reporte"})
		return
	}

	// Limpiar caché si se eliminó el comentario
	if req.Action == "delete" && videoID > 0 {
		if Cache != nil {
			cacheKey := fmt.Sprintf("comments:video:%d", videoID)
			Cache.Delete(ctx, cacheKey)
		}
	}

	c.JSON(http.StatusOK, gin.H{
		"message": "Reporte resuelto correctamente",
	})
}

// handleAdminDeleteComment elimina un comentario sin verificar autoría.
// DELETE /api/v1/admin/comments/:id
// Requiere: Moderador (5+)
func handleAdminDeleteComment(c *gin.Context) {
	commentID, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "ID de comentario inválido"})
		return
	}

	ctx, cancel := context.WithTimeout(c.Request.Context(), 5*time.Second)
	defer cancel()

	if err := Repos.Admin.DeleteComment(ctx, commentID); err != nil {
		Logger.Error("Error eliminando comentario",
			"comment_id", commentID, "error", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Error eliminando comentario"})
		return
	}

	// Invalidar caché de comentarios
	if Cache != nil {
		Cache.InvalidateComments(ctx, 0) // Invalidar todos los caches de comentarios
	}

	adminID := int(c.GetFloat64("userID"))
	Logger.Info("Admin eliminó comentario",
		"admin_id", adminID, "comment_id", commentID)

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"message": "Comentario eliminado correctamente",
	})
}

// --- Helpers ---

// parsePagination extrae y valida los parámetros de paginación de la query string.
// Valores por defecto: page=1, page_size=20. Máximo page_size=100.
func parsePagination(c *gin.Context) (int, int) {
	page, err := strconv.Atoi(c.DefaultQuery("page", "1"))
	if err != nil || page < 1 {
		page = 1
	}

	pageSize, err := strconv.Atoi(c.DefaultQuery("page_size", "20"))
	if err != nil || pageSize < 1 {
		pageSize = 20
	}
	if pageSize > 100 {
		pageSize = 100
	}

	return page, pageSize
}
