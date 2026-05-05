package main

import (
	"context"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
)

// Constantes de niveles de acceso.
// Estos valores corresponden a tipos_usuario.nivel_acceso en la BD.
const (
	AccessLevelStudent   = 1  // Estudiante (usuario regular)
	AccessLevelProfessor = 3  // Profesor (puede subir contenido)
	AccessLevelModerator = 5  // Moderador (puede moderar contenido)
	AccessLevelAdmin     = 10 // Administrador (acceso total)
)

// AdminMiddleware verifica que el usuario autenticado tenga permisos de administrador o superior.
// Requiere que AuthMiddleware() se ejecute antes (para que userID esté en el contexto).
// Consulta tipos_usuario.nivel_acceso para verificar el rol.
//
// Niveles de acceso:
//   - 1: Estudiante (sin acceso admin)
//   - 3: Profesor (puede subir contenido)
//   - 5: Moderador (acceso parcial)
//   - 10: Administrador (acceso total)
func AdminMiddleware(minAccessLevel int) gin.HandlerFunc {
	return func(c *gin.Context) {
		// Obtener userID del contexto (puesto por AuthMiddleware)
		userIDFloat, exists := c.Get("userID")
		if !exists {
			c.JSON(http.StatusUnauthorized, gin.H{
				"error": "Autenticación requerida",
			})
			c.Abort()
			return
		}

		userID := int(userIDFloat.(float64))

		// Consultar nivel de acceso del usuario en la BD
		ctx, cancel := context.WithTimeout(c.Request.Context(), 3*time.Second)
		defer cancel()

		accessLevel, err := Repos.Admin.GetUserAccessLevel(ctx, userID)
		if err != nil {
			Logger.Warn("Error verificando permisos de admin",
				"user_id", userID, "error", err)
			c.JSON(http.StatusForbidden, gin.H{
				"error": "No se pudieron verificar los permisos",
			})
			c.Abort()
			return
		}

		// Verificar nivel de acceso mínimo requerido
		if accessLevel < minAccessLevel {
			Logger.Warn("Acceso admin denegado",
				"user_id", userID,
				"access_level", accessLevel,
				"required_level", minAccessLevel)
			c.JSON(http.StatusForbidden, gin.H{
				"error": "No tienes permisos suficientes para esta acción",
			})
			c.Abort()
			return
		}

		// Guardar nivel de acceso en el contexto para uso en handlers
		c.Set("accessLevel", accessLevel)
		Logger.Debug("Acceso admin autorizado",
			"user_id", userID, "access_level", accessLevel)
		c.Next()
	}
}

// RequireAdmin es un shortcut para AdminMiddleware con nivel de acceso de administrador (10).
func RequireAdmin() gin.HandlerFunc {
	return AdminMiddleware(AccessLevelAdmin)
}

// RequireModerator es un shortcut para AdminMiddleware con nivel de acceso de moderador (5).
func RequireModerator() gin.HandlerFunc {
	return AdminMiddleware(AccessLevelModerator)
}

// RequireProfessor es un shortcut para AdminMiddleware con nivel de acceso de profesor (3).
func RequireProfessor() gin.HandlerFunc {
	return AdminMiddleware(AccessLevelProfessor)
}

// SelfOrAdminMiddleware permite que un usuario acceda a su propio recurso O que un admin acceda a cualquiera.
// Útil para endpoints como "ver perfil de usuario" donde el dueño o un admin pueden acceder.
func SelfOrAdminMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		userIDFloat, exists := c.Get("userID")
		if !exists {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Autenticación requerida"})
			c.Abort()
			return
		}
		userID := int(userIDFloat.(float64))

		// Si está accediendo a un recurso de otro usuario, verificar que sea admin
		targetUserID := c.GetInt("targetUserID")
		if targetUserID > 0 && targetUserID != userID {
			ctx, cancel := context.WithTimeout(c.Request.Context(), 3*time.Second)
			defer cancel()

			accessLevel, err := Repos.Admin.GetUserAccessLevel(ctx, userID)
			if err != nil || accessLevel < AccessLevelModerator {
				c.JSON(http.StatusForbidden, gin.H{
					"error": "No tienes permisos para acceder a este recurso",
				})
				c.Abort()
				return
			}
			c.Set("accessLevel", accessLevel)
		}

		c.Next()
	}
}
