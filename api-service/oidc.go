package main

import (
	"context"
	"fmt"
	"time"
)

// =============================================================================
// Identity Broker — Sistema OIDC para UTBGO
// =============================================================================
// Actúa como un broker de identidad centralizado que:
//   - Acepta ID Tokens de múltiples proveedores (Google, Microsoft Entra ID)
//   - Valida cada token usando OIDC Discovery + JWKS del proveedor
//   - Extrae claims estandarizados (email, nombre, foto)
//   - Mapea el rol del usuario según dominio del correo
//   - Emite un JWT propio unificado con rol incluido
//
// Variables de entorno requeridas:
//   - GOOGLE_CLIENT_ID: Client ID de Google OAuth
//   - AZURE_CLIENT_ID: Client ID de Microsoft Entra ID
//   - AZURE_TENANT_ID: Tenant ID de Azure AD
//   - INSTITUTIONAL_DOMAIN: Dominio institucional (ej: utb.edu.co)
//   - ADMIN_DOMAIN: Dominio de administradores (ej: admin.utb.edu.co)
// =============================================================================

// OIDCProvider define la interfaz que cada proveedor de identidad debe implementar.
// Sigue el principio de Interface Segregation: solo expone lo necesario
// para validar tokens y obtener claims estandarizados.
type OIDCProvider interface {
	// ValidateIDToken verifica la firma del ID Token usando JWKS del proveedor,
	// valida la audiencia y expiración, y extrae los claims estandarizados.
	ValidateIDToken(ctx context.Context, rawIDToken string) (*OIDCClaims, error)

	// ProviderName retorna el identificador único del proveedor (ej: "google", "microsoft").
	ProviderName() string
}

// OIDCClaims contiene los claims estandarizados extraídos de cualquier proveedor OIDC.
// Normaliza las diferencias entre proveedores (Google usa "email", Microsoft
// usa "preferred_username") en una estructura uniforme.
type OIDCClaims struct {
	Subject  string // ID único del usuario en el proveedor (claim "sub")
	Email    string // Correo electrónico verificado
	Name     string // Nombre completo del usuario
	Picture  string // URL del avatar/foto del usuario
	Provider string // Nombre del proveedor que emitió el token original
}

// AuthResult contiene el resultado exitoso de una autenticación vía Identity Broker.
// Incluye los tokens JWT propios y la información del usuario autenticado.
type AuthResult struct {
	AccessToken  string    `json:"access_token"`
	RefreshToken string    `json:"refresh_token"`
	ExpiresIn    int64     `json:"expires_in"`
	User         AuthUser  `json:"user"`
}

// AuthUser contiene la información del usuario incluida en la respuesta de autenticación.
type AuthUser struct {
	ID       int    `json:"id"`
	Email    string `json:"email"`
	Name     string `json:"name"`
	Role     string `json:"role"`
	Provider string `json:"provider"`
	Avatar   string `json:"avatar_url,omitempty"`
}

// IdentityBroker orquesta la autenticación con múltiples proveedores OIDC.
// Es el punto de entrada único para toda autenticación externa.
//
// Responsabilidades (Single Responsibility):
//   - Seleccionar el proveedor correcto según el parámetro de la request
//   - Delegar la validación del token al proveedor seleccionado
//   - Delegar el mapeo de roles al RoleMapper
//   - Crear o actualizar el usuario en la base de datos
//   - Emitir tokens JWT propios vía AuthService
type IdentityBroker struct {
	providers  map[string]OIDCProvider
	roleMapper *RoleMapper
	auth       *AuthService
}

// NewIdentityBroker crea una nueva instancia del broker. Recibe los proveedores
// ya inicializados (Open/Closed Principle: se pueden agregar más proveedores
// sin modificar este código).
func NewIdentityBroker(auth *AuthService, roleMapper *RoleMapper, providers ...OIDCProvider) *IdentityBroker {
	providerMap := make(map[string]OIDCProvider, len(providers))
	for _, p := range providers {
		providerMap[p.ProviderName()] = p
		Logger.Info("Identity Broker: proveedor OIDC registrado",
			"provider", p.ProviderName(),
		)
	}

	return &IdentityBroker{
		providers:  providerMap,
		roleMapper: roleMapper,
		auth:       auth,
	}
}

// AvailableProviders retorna la lista de proveedores OIDC registrados.
func (ib *IdentityBroker) AvailableProviders() []string {
	names := make([]string, 0, len(ib.providers))
	for name := range ib.providers {
		names = append(names, name)
	}
	return names
}

// Authenticate ejecuta el flujo completo de autenticación:
//  1. Selecciona el proveedor OIDC por nombre
//  2. Valida el ID Token con JWKS del proveedor
//  3. Extrae claims estandarizados
//  4. Mapea el rol del usuario según dominio del email
//  5. Crea o actualiza el usuario en PostgreSQL
//  6. Emite un par de tokens JWT propios
func (ib *IdentityBroker) Authenticate(ctx context.Context, providerName, rawIDToken string) (*AuthResult, *APIError) {
	startTime := time.Now()

	// 1. Seleccionar proveedor
	provider, exists := ib.providers[providerName]
	if !exists {
		return nil, ErrInvalidInput("provider",
			fmt.Sprintf("Proveedor '%s' no soportado. Disponibles: %v", providerName, ib.AvailableProviders()))
	}

	// 2. Validar ID Token con OIDC Discovery + JWKS
	claims, err := provider.ValidateIDToken(ctx, rawIDToken)
	if err != nil {
		Logger.Warn("Identity Broker: token inválido",
			"provider", providerName,
			"error", err,
			"duration_ms", time.Since(startTime).Milliseconds(),
		)
		return nil, ErrUnauthorized().WithDetails("Token de " + providerName + " inválido o expirado")
	}

	if claims.Email == "" {
		return nil, ErrInvalidInput("email", "El token no contiene un correo electrónico válido")
	}

	Logger.Info("Identity Broker: token validado",
		"provider", providerName,
		"email", claims.Email,
		"duration_ms", time.Since(startTime).Milliseconds(),
	)

	// 3. Validar proveedor/dominio y resolver rol permitido
	roleCode, apiErr := ib.roleMapper.RoleForOIDC(claims.Email, claims.Provider)
	if apiErr != nil {
		return nil, apiErr
	}

	// 4. Crear o actualizar usuario en la base de datos
	userID, err := ib.upsertUser(ctx, claims, roleCode)
	if err != nil {
		Logger.Error("Identity Broker: error al crear/actualizar usuario",
			"email", claims.Email,
			"error", err,
		)
		return nil, ErrInternal().WithDetails("Error al procesar el usuario")
	}

	// 5. Emitir tokens JWT propios con rol incluido
	tokenPair, err := ib.auth.GenerateTokenPairWithRole(userID, roleCode)
	if err != nil {
		Logger.Error("Identity Broker: error al generar tokens",
			"user_id", userID,
			"error", err,
		)
		return nil, ErrInternal().WithDetails("Error al generar tokens de sesión")
	}

	Logger.Info("Identity Broker: autenticación exitosa",
		"provider", providerName,
		"email", claims.Email,
		"role", roleCode,
		"user_id", userID,
		"duration_ms", time.Since(startTime).Milliseconds(),
	)

	return &AuthResult{
		AccessToken:  tokenPair.AccessToken,
		RefreshToken: tokenPair.RefreshToken,
		ExpiresIn:    3600, // 1 hora
		User: AuthUser{
			ID:       userID,
			Email:    claims.Email,
			Name:     claims.Name,
			Role:     roleCode,
			Provider: claims.Provider,
			Avatar:   claims.Picture,
		},
	}, nil
}

// upsertUser crea un nuevo usuario o actualiza uno existente en la base de datos.
// Usa getOrCreateUser existente y luego actualiza el rol si es necesario.
func (ib *IdentityBroker) upsertUser(ctx context.Context, claims *OIDCClaims, roleCode string) (int, error) {
	// Usar la función existente para crear/buscar usuario
	userID, err := getOrCreateUser(ctx, claims.Email, claims.Name, claims.Picture, roleCode)
	if err != nil {
		return 0, fmt.Errorf("error en getOrCreateUser: %w", err)
	}

	// Actualizar el rol del usuario según el mapeo del Identity Broker
	err = ib.updateUserRole(ctx, userID, roleCode)
	if err != nil {
		Logger.Warn("Identity Broker: no se pudo actualizar el rol",
			"user_id", userID,
			"role", roleCode,
			"error", err,
		)
		// No es un error fatal: el usuario ya existe, simplemente no se actualizó el rol
	}

	return userID, nil
}

// updateUserRole actualiza el tipo de usuario según el código de rol mapeado.
func (ib *IdentityBroker) updateUserRole(ctx context.Context, userID int, roleCode string) error {
	_, err := DB.ExecContext(ctx, `
		UPDATE usuarios 
		SET id_tipo_usuario = (
			SELECT id_tipo_usuario FROM tipos_usuario WHERE codigo = $1
		)
		WHERE id_usuario = $2
	`, roleCode, userID)
	return err
}

// Broker es la instancia global del Identity Broker.
// Es nil si no se configuraron proveedores OIDC.
var Broker *IdentityBroker
