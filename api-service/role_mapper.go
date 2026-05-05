package main

import (
	"fmt"
	"os"
	"strings"
)

// =============================================================================
// RoleMapper — Mapeo de Roles por Dominio de Correo
// =============================================================================
// Centraliza la política de autenticación pública de la aplicación.
//
// Reglas vigentes:
//   1. Registro local:
//      - @utb.edu.co      → estudiante
//      - @doc.utb.edu.co  → profesor
//   2. Google/Firebase:
//      - solo @gmail.com  → aspirante
//   3. admin/moderador:
//      - no se asignan automáticamente desde flujos públicos;
//        son roles gestionados manualmente por administración.
//
// Variables de entorno:
//   - STUDENT_DOMAIN: dominio de estudiantes (ej: utb.edu.co)
//   - PROFESSOR_DOMAIN: dominio de profesores (ej: doc.utb.edu.co)
//   - ASPIRANT_GOOGLE_DOMAIN: dominio permitido para Google (ej: gmail.com)
// =============================================================================

// Códigos de rol que corresponden a la tabla tipos_usuario en PostgreSQL.
const (
	RoleAdmin      = "admin"
	RoleModerador  = "moderador"
	RoleProfesor   = "profesor"
	RoleEstudiante = "estudiante"
	RoleAspirante  = "aspirante"
)

// RoleMapper mapea emails y proveedores a roles del sistema.
type RoleMapper struct {
	studentDomain         string // ej: "utb.edu.co"
	professorDomain       string // ej: "doc.utb.edu.co"
	aspirantGoogleDomain  string // ej: "gmail.com"
}

// NewRoleMapper crea un nuevo mapper con configuración desde variables de entorno.
// Si las variables no están configuradas, usa valores por defecto razonables.
func NewRoleMapper() *RoleMapper {
	studentDomain := os.Getenv("STUDENT_DOMAIN")
	if studentDomain == "" {
		studentDomain = "utb.edu.co"
	}

	professorDomain := os.Getenv("PROFESSOR_DOMAIN")
	if professorDomain == "" {
		professorDomain = "doc.utb.edu.co"
	}

	aspirantGoogleDomain := os.Getenv("ASPIRANT_GOOGLE_DOMAIN")
	if aspirantGoogleDomain == "" {
		aspirantGoogleDomain = "gmail.com"
	}

	Logger.Info("RoleMapper inicializado",
		"student_domain", studentDomain,
		"professor_domain", professorDomain,
		"aspirant_google_domain", aspirantGoogleDomain,
	)

	return &RoleMapper{
		studentDomain:        strings.ToLower(studentDomain),
		professorDomain:      strings.ToLower(professorDomain),
		aspirantGoogleDomain: strings.ToLower(aspirantGoogleDomain),
	}
}

func (rm *RoleMapper) NormalizeEmail(email string) string {
	return strings.ToLower(strings.TrimSpace(email))
}

// RoleForRegistration valida y resuelve el rol para el flujo de registro local.
func (rm *RoleMapper) RoleForRegistration(email string) (string, *APIError) {
	email = rm.NormalizeEmail(email)
	domain := rm.extractDomain(email)
	if domain == "" {
		return "", ErrInvalidInput("email", "El correo no tiene un dominio válido")
	}

	switch domain {
	case rm.professorDomain:
		return RoleProfesor, nil
	case rm.studentDomain:
		return RoleEstudiante, nil
	default:
		return "", ErrInvalidInput(
			"email",
			fmt.Sprintf("Solo se permite registro con correos @%s o @%s", rm.studentDomain, rm.professorDomain),
		)
	}
}

// RoleForOIDC valida y resuelve el rol para proveedores externos.
// En la política actual, Google/Firebase solo se permite para aspirantes con @gmail.com.
func (rm *RoleMapper) RoleForOIDC(email, provider string) (string, *APIError) {
	email = strings.ToLower(strings.TrimSpace(email))
	provider = strings.ToLower(strings.TrimSpace(provider))

	domain := rm.extractDomain(email)
	if domain == "" {
		return "", ErrInvalidInput("email", "El correo no tiene un dominio válido")
	}

	if provider != firebaseProviderName {
		return "", ErrForbidden("Solo se permite acceso externo con Google")
	}

	if domain != rm.aspirantGoogleDomain {
		return "", ErrForbidden(
			fmt.Sprintf("El acceso con Google solo está permitido para correos @%s", rm.aspirantGoogleDomain),
		)
	}

	Logger.Info("RoleMapper: asignado rol aspirante (Google/Firebase)",
		"email", email,
		"provider", provider,
	)
	return RoleAspirante, nil
}

// CanUsePasswordLogin define qué roles pueden autenticarse por email/password.
func (rm *RoleMapper) CanUsePasswordLogin(role string) bool {
	return strings.ToLower(strings.TrimSpace(role)) != RoleAspirante
}

// extractDomain extrae el dominio de un email.
// Ejemplo: "usuario@utb.edu.co" → "utb.edu.co"
func (rm *RoleMapper) extractDomain(email string) string {
	parts := strings.SplitN(email, "@", 2)
	if len(parts) != 2 {
		return ""
	}
	return strings.ToLower(parts[1])
}
