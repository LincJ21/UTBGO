package main

import (
	"net/http"

	"github.com/gin-gonic/gin"
)

// =============================================================================
// Handlers OIDC — Identity Broker
// =============================================================================
// Handlers HTTP para el flujo de autenticación unificado vía OIDC.
// Todos los proveedores (Google, Microsoft) se manejan desde un único endpoint:
//   POST /api/v1/auth/oidc/:provider
//
// El :provider determina qué OIDCProvider del broker se utiliza para
// validar el ID Token recibido.
// =============================================================================

// oidcAuthRequest es el DTO para la petición de autenticación OIDC.
type oidcAuthRequest struct {
	Token string `json:"token" binding:"required"`
}

// handleOIDCAuth es el handler unificado para autenticación vía Identity Broker.
//
// Flujo:
//  1. Extrae el proveedor de la URL (:provider)
//  2. Parsea el body para obtener el ID Token
//  3. Delega al IdentityBroker.Authenticate()
//  4. Retorna access_token + refresh_token + info del usuario
//
// Endpoint: POST /api/v1/auth/oidc/:provider
// Body:     {"token": "<id_token_del_proveedor>"}
// Response: {"access_token": "...", "refresh_token": "...", "expires_in": 3600, "user": {...}}
func handleOIDCAuth(c *gin.Context) {
	// Verificar que el Identity Broker está disponible
	if Broker == nil {
		RespondError(c, ErrInternal().WithDetails("Identity Broker no configurado"))
		return
	}

	// Extraer el nombre del proveedor de la URL
	providerName := c.Param("provider")
	if providerName == "" {
		RespondError(c, ErrMissingField("provider"))
		return
	}

	// Parsear y validar el body de la petición
	var req oidcAuthRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		RespondError(c, ErrValidation("Se requiere un campo 'token' con el ID Token del proveedor"))
		return
	}

	// Delegar al Identity Broker
	result, apiErr := Broker.Authenticate(c.Request.Context(), providerName, req.Token)
	if apiErr != nil {
		RespondError(c, apiErr)
		return
	}

	// Respuesta exitosa
	RespondSuccess(c, result)
}

// handleOIDCProviders retorna la lista de proveedores OIDC disponibles.
//
// Endpoint: GET /api/v1/auth/oidc/providers
// Response: {"providers": ["google", "microsoft"]}
func handleOIDCProviders(c *gin.Context) {
	if Broker == nil {
		c.JSON(http.StatusOK, gin.H{"providers": []string{}})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"providers": Broker.AvailableProviders(),
	})
}
