package main

import (
	"context"
	"fmt"
	"os"

	"github.com/coreos/go-oidc/v3/oidc"
)

// FirebaseOIDCProvider implementa OIDCProvider para Firebase Auth
type FirebaseOIDCProvider struct {
	verifier *oidc.IDTokenVerifier
}

// NewFirebaseOIDCProvider crea una nueva instancia del proveedor de Firebase
func NewFirebaseOIDCProvider(ctx context.Context) (*FirebaseOIDCProvider, error) {
	projectID := os.Getenv("FIREBASE_PROJECT_ID")
	if projectID == "" {
		return nil, fmt.Errorf("FIREBASE_PROJECT_ID no configurado")
	}

	issuer := fmt.Sprintf("https://securetoken.google.com/%s", projectID)
	provider, err := oidc.NewProvider(ctx, issuer)
	if err != nil {
		return nil, fmt.Errorf("error al obtener el proveedor de Firebase: %w", err)
	}

	config := &oidc.Config{
		ClientID: projectID,
	}
	verifier := provider.Verifier(config)

	return &FirebaseOIDCProvider{
		verifier: verifier,
	}, nil
}

// ProviderName retorna el identificador único del proveedor
func (p *FirebaseOIDCProvider) ProviderName() string {
	return "firebase"
}

// ValidateIDToken verifica el token de Firebase contra el issuer oficial
func (p *FirebaseOIDCProvider) ValidateIDToken(ctx context.Context, rawToken string) (*OIDCClaims, error) {
	token, err := p.verifier.Verify(ctx, rawToken)
	if err != nil {
		return nil, fmt.Errorf("error al validar token de Firebase: %w", err)
	}

	var claims struct {
		Email         string `json:"email"`
		EmailVerified bool   `json:"email_verified" `
		Name          string `json:"name"`
		Picture       string `json:"picture"`
		Sub           string `json:"sub"`
	}

	if err := token.Claims(&claims); err != nil {
		return nil, fmt.Errorf("error al extraer claims de Firebase: %w", err)
	}

	return &OIDCClaims{
		Email:    claims.Email,
		Name:     claims.Name,
		Picture:  claims.Picture,
		Subject:  claims.Sub,
		Provider: "firebase",
	}, nil
}
