package main

import (
	"context"
	"fmt"
	"os"

	"github.com/coreos/go-oidc/v3/oidc"
)

// =============================================================================
// Google OIDC Provider
// =============================================================================
// Valida ID Tokens de Google usando OIDC Discovery + JWKS.
// A diferencia de la implementación anterior (que usaba google.golang.org/api/idtoken),
// esta usa el estándar OIDC completo para verificación criptográfica local.
//
// OIDC Discovery URL: https://accounts.google.com/.well-known/openid-configuration
// JWKS URL (auto-descubierta): https://www.googleapis.com/oauth2/v3/certs
//
// Variable de entorno requerida:
//   - GOOGLE_CLIENT_ID: Client ID de OAuth (aud del token)
// =============================================================================

const (
	googleIssuer       = "https://accounts.google.com"
	googleProviderName = "google"
)

// GoogleOIDCProvider implementa OIDCProvider para Google.
type GoogleOIDCProvider struct {
	verifier *oidc.IDTokenVerifier
	clientID string
}

// NewGoogleOIDCProvider inicializa el proveedor de Google.
// Descarga el JWKS de Google vía OIDC Discovery y configura el verificador.
func NewGoogleOIDCProvider(ctx context.Context) (*GoogleOIDCProvider, error) {
	clientID := os.Getenv("GOOGLE_CLIENT_ID")
	if clientID == "" {
		return nil, fmt.Errorf("GOOGLE_CLIENT_ID no está configurado en .env")
	}

	// Descubrir la configuración OIDC de Google y descargar JWKS
	provider, err := oidc.NewProvider(ctx, googleIssuer)
	if err != nil {
		return nil, fmt.Errorf("error al descubrir OIDC de Google: %w", err)
	}

	// Configurar el verificador con la audiencia esperada
	verifier := provider.Verifier(&oidc.Config{
		ClientID: clientID,
	})

	Logger.Info("Google OIDC Provider inicializado",
		"issuer", googleIssuer,
		"client_id_length", len(clientID),
	)

	return &GoogleOIDCProvider{
		verifier: verifier,
		clientID: clientID,
	}, nil
}

// ProviderName retorna "google".
func (g *GoogleOIDCProvider) ProviderName() string {
	return googleProviderName
}

// ValidateIDToken verifica un ID Token de Google usando JWKS.
// Valida la firma criptográfica, el issuer (accounts.google.com),
// la audiencia (GOOGLE_CLIENT_ID) y la expiración.
func (g *GoogleOIDCProvider) ValidateIDToken(ctx context.Context, rawIDToken string) (*OIDCClaims, error) {
	// Verificar firma + aud + exp + iss automáticamente
	idToken, err := g.verifier.Verify(ctx, rawIDToken)
	if err != nil {
		return nil, fmt.Errorf("token de Google inválido: %w", err)
	}

	// Extraer claims del token verificado
	var googleClaims struct {
		Email         string `json:"email"`
		EmailVerified bool   `json:"email_verified"`
		Name          string `json:"name"`
		Picture       string `json:"picture"`
		GivenName     string `json:"given_name"`
		FamilyName    string `json:"family_name"`
	}

	if err := idToken.Claims(&googleClaims); err != nil {
		return nil, fmt.Errorf("error extrayendo claims de Google: %w", err)
	}

	// Verificar que el email esté verificado por Google
	if !googleClaims.EmailVerified {
		return nil, fmt.Errorf("el email %s no está verificado por Google", googleClaims.Email)
	}

	// Construir nombre si no viene completo
	name := googleClaims.Name
	if name == "" && googleClaims.GivenName != "" {
		name = googleClaims.GivenName
		if googleClaims.FamilyName != "" {
			name += " " + googleClaims.FamilyName
		}
	}
	if name == "" {
		name = googleClaims.Email // Fallback al email
	}

	return &OIDCClaims{
		Subject:  idToken.Subject,
		Email:    googleClaims.Email,
		Name:     name,
		Picture:  googleClaims.Picture,
		Provider: googleProviderName,
	}, nil
}
