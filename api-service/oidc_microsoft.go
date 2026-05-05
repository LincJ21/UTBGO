package main

import (
	"context"
	"fmt"
	"os"

	"github.com/coreos/go-oidc/v3/oidc"
)

// =============================================================================
// Microsoft Entra ID (Azure AD) OIDC Provider
// =============================================================================
// Valida ID Tokens de Microsoft Entra ID usando OIDC Discovery + JWKS.
// Soporta el flujo de acceso institucional para estudiantes, profesores
// y administrativos que usan sus cuentas @utb.edu.co.
//
// OIDC Discovery URL:
//   https://login.microsoftonline.com/{tenant}/v2.0/.well-known/openid-configuration
// JWKS URL (auto-descubierta):
//   https://login.microsoftonline.com/{tenant}/discovery/v2.0/keys
//
// Variables de entorno requeridas:
//   - AZURE_CLIENT_ID: Application (client) ID del App Registration
//   - AZURE_TENANT_ID: Directory (tenant) ID de Azure AD
//   - AZURE_CLIENT_SECRET: Client secret (para flujo de código de autorización)
// =============================================================================

const (
	microsoftIssuerTemplate = "https://login.microsoftonline.com/%s/v2.0"
	microsoftProviderName   = "microsoft"
)

// MicrosoftOIDCProvider implementa OIDCProvider para Microsoft Entra ID.
type MicrosoftOIDCProvider struct {
	verifier *oidc.IDTokenVerifier
	clientID string
	tenantID string
}

// NewMicrosoftOIDCProvider inicializa el proveedor de Microsoft Entra ID.
// Descarga el JWKS de Azure AD vía OIDC Discovery y configura el verificador.
func NewMicrosoftOIDCProvider(ctx context.Context) (*MicrosoftOIDCProvider, error) {
	clientID := os.Getenv("AZURE_CLIENT_ID")
	tenantID := os.Getenv("AZURE_TENANT_ID")

	if clientID == "" {
		return nil, fmt.Errorf("AZURE_CLIENT_ID no está configurado en .env")
	}
	if tenantID == "" {
		return nil, fmt.Errorf("AZURE_TENANT_ID no está configurado en .env")
	}

	// Construir el issuer URL con el tenant específico
	issuerURL := fmt.Sprintf(microsoftIssuerTemplate, tenantID)

	// Descubrir la configuración OIDC de Microsoft y descargar JWKS
	provider, err := oidc.NewProvider(ctx, issuerURL)
	if err != nil {
		return nil, fmt.Errorf("error al descubrir OIDC de Microsoft Entra ID: %w", err)
	}

	// Configurar el verificador con la audiencia esperada
	verifier := provider.Verifier(&oidc.Config{
		ClientID: clientID,
	})

	Logger.Info("Microsoft Entra ID OIDC Provider inicializado",
		"issuer", issuerURL,
		"tenant_id", tenantID,
		"client_id_length", len(clientID),
	)

	return &MicrosoftOIDCProvider{
		verifier: verifier,
		clientID: clientID,
		tenantID: tenantID,
	}, nil
}

// ProviderName retorna "microsoft".
func (m *MicrosoftOIDCProvider) ProviderName() string {
	return microsoftProviderName
}

// ValidateIDToken verifica un ID Token de Microsoft Entra ID usando JWKS.
// Valida la firma criptográfica, el issuer (login.microsoftonline.com/{tenant}/v2.0),
// la audiencia (AZURE_CLIENT_ID) y la expiración.
//
// Microsoft puede enviar el email en diferentes claims según la configuración:
//   - "email": si está disponible
//   - "preferred_username": UPN del usuario (generalmente email@dominio)
//   - "upn": User Principal Name (en tokens de v1)
func (m *MicrosoftOIDCProvider) ValidateIDToken(ctx context.Context, rawIDToken string) (*OIDCClaims, error) {
	// Verificar firma + aud + exp + iss automáticamente
	idToken, err := m.verifier.Verify(ctx, rawIDToken)
	if err != nil {
		return nil, fmt.Errorf("token de Microsoft inválido: %w", err)
	}

	// Extraer claims del token verificado.
	// Microsoft Entra ID puede incluir diferentes claims
	// dependiendo de la configuración del App Registration.
	var msClaims struct {
		Email             string `json:"email"`
		PreferredUsername string `json:"preferred_username"`
		UPN               string `json:"upn"`
		Name              string `json:"name"`
		GivenName         string `json:"given_name"`
		FamilyName        string `json:"family_name"`
		Picture           string `json:"picture"`
	}

	if err := idToken.Claims(&msClaims); err != nil {
		return nil, fmt.Errorf("error extrayendo claims de Microsoft: %w", err)
	}

	// Resolver el email con fallback chain:
	// email → preferred_username → upn
	email := msClaims.Email
	if email == "" {
		email = msClaims.PreferredUsername
	}
	if email == "" {
		email = msClaims.UPN
	}
	if email == "" {
		return nil, fmt.Errorf("el token de Microsoft no contiene email ni UPN")
	}

	// Construir nombre completo con fallback
	name := msClaims.Name
	if name == "" && msClaims.GivenName != "" {
		name = msClaims.GivenName
		if msClaims.FamilyName != "" {
			name += " " + msClaims.FamilyName
		}
	}
	if name == "" {
		name = email // Fallback al email
	}

	return &OIDCClaims{
		Subject:  idToken.Subject,
		Email:    email,
		Name:     name,
		Picture:  msClaims.Picture,
		Provider: microsoftProviderName,
	}, nil
}
