package main

import (
	"os"
	"strings"
)

// =============================================================================
// RoleMapper — Mapeo de Roles por Dominio de Correo
// =============================================================================
// Determina el rol del usuario basándose en el dominio de su correo electrónico
// y el proveedor OIDC que utilizó para autenticarse.
//
// Reglas de mapeo (en orden de prioridad):
//   1. Email @admin.utb.edu.co             → admin       (nivel 10)
//   2. Microsoft + @utb.edu.co             → profesor    (nivel 3)
//   3. Google/cualquiera + @utb.edu.co     → estudiante  (nivel 1)
//   4. Cualquier otro dominio              → aspirante   (nivel 1)
//
// Variables de entorno:
//   - INSTITUTIONAL_DOMAIN: dominio institucional (ej: utb.edu.co)
//   - ADMIN_DOMAIN: subdominio de administración (ej: admin.utb.edu.co)
// =============================================================================

// Códigos de rol que corresponden a la tabla tipos_usuario en PostgreSQL.
const (
	RoleAdmin      = "admin"
	RoleProfesor   = "profesor"
	RoleEstudiante = "estudiante"
	RoleAspirante  = "aspirante"
)

// RoleMapper mapea emails y proveedores a roles del sistema.
type RoleMapper struct {
	institutionalDomain string   // ej: "utb.edu.co"
	adminDomain         string   // ej: "admin.utb.edu.co"
	adminEmails         []string // Lista de correos específicos con rol admin
}

// NewRoleMapper crea un nuevo mapper con configuración desde variables de entorno.
// Si las variables no están configuradas, usa valores por defecto razonables.
func NewRoleMapper() *RoleMapper {
	institutionalDomain := os.Getenv("INSTITUTIONAL_DOMAIN")
	if institutionalDomain == "" {
		institutionalDomain = "utb.edu.co"
	}

	adminDomain := os.Getenv("ADMIN_DOMAIN")
	if adminDomain == "" {
		adminDomain = "admin.utb.edu.co"
	}

	adminEmailsStr := os.Getenv("ADMIN_EMAILS")
	var adminEmails []string
	if adminEmailsStr != "" {
		parts := strings.Split(adminEmailsStr, ",")
		for _, p := range parts {
			email := strings.ToLower(strings.TrimSpace(p))
			if email != "" {
				adminEmails = append(adminEmails, email)
			}
		}
	}

	Logger.Info("RoleMapper inicializado",
		"institutional_domain", institutionalDomain,
		"admin_domain", adminDomain,
		"admin_emails_count", len(adminEmails),
	)

	return &RoleMapper{
		institutionalDomain: strings.ToLower(institutionalDomain),
		adminDomain:         strings.ToLower(adminDomain),
		adminEmails:         adminEmails,
	}
}

// MapRole determina el rol del usuario según su email y proveedor de autenticación.
//
// La lógica de prioridad es:
//  1. Si el email pertenece al dominio de admin → admin
//  2. Si usó Microsoft Y el email es del dominio institucional → profesor
//  3. Si el email es del dominio institucional (cualquier proveedor) → estudiante
//  4. Para cualquier otro caso → aspirante
func (rm *RoleMapper) MapRole(email, provider string) string {
	email = strings.ToLower(strings.TrimSpace(email))
	provider = strings.ToLower(strings.TrimSpace(provider))

	domain := rm.extractDomain(email)
	if domain == "" {
		Logger.Warn("RoleMapper: email sin dominio válido", "email", email)
		return RoleAspirante
	}

	// 0. Whitelist de correos específicos → admin (Prioridad Máxima)
	for _, adminEmail := range rm.adminEmails {
		if email == adminEmail {
			Logger.Info("RoleMapper: asignado rol admin por whitelist de email",
				"email", email,
			)
			return RoleAdmin
		}
	}

	// 1. Dominio de administración → admin
	if domain == rm.adminDomain {
		Logger.Info("RoleMapper: asignado rol admin",
			"email", email,
			"domain", domain,
		)
		return RoleAdmin
	}

	// 2. Microsoft + dominio institucional → profesor
	if provider == microsoftProviderName && rm.isInstitutionalDomain(domain) {
		Logger.Info("RoleMapper: asignado rol profesor (Microsoft + institucional)",
			"email", email,
			"provider", provider,
		)
		return RoleProfesor
	}

	// 3. Dominio institucional (cualquier proveedor) → estudiante
	if rm.isInstitutionalDomain(domain) {
		Logger.Info("RoleMapper: asignado rol estudiante (institucional)",
			"email", email,
			"provider", provider,
		)
		return RoleEstudiante
	}

	// 4. Dominio externo → aspirante
	Logger.Info("RoleMapper: asignado rol aspirante (externo)",
		"email", email,
		"provider", provider,
		"domain", domain,
	)
	return RoleAspirante
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

// isInstitutionalDomain verifica si un dominio pertenece a la institución.
// Soporta el dominio exacto y subdominios (ej: "sub.utb.edu.co" también coincide).
func (rm *RoleMapper) isInstitutionalDomain(domain string) bool {
	// Coincidencia exacta
	if domain == rm.institutionalDomain {
		return true
	}

	// Coincidencia con subdominio (ej: "correo.utb.edu.co")
	if strings.HasSuffix(domain, "."+rm.institutionalDomain) {
		return true
	}

	return false
}
