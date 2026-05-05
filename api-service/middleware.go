package main

import (
	"net/http"
	"sync"
	"time"

	"github.com/gin-gonic/gin"
)

// RateLimiter implementa un rate limiter simple basado en token bucket por IP.
// Para producción real, considera usar Redis para soportar múltiples instancias.
type RateLimiter struct {
	visitors map[string]*visitor
	mu       sync.RWMutex
	rate     int           // Requests permitidos por ventana
	window   time.Duration // Ventana de tiempo
}

type visitor struct {
	count    int
	lastSeen time.Time
}

// NewRateLimiter crea un nuevo rate limiter.
// rate: número máximo de requests permitidos en la ventana de tiempo.
// window: duración de la ventana (ej: 1 minuto).
func NewRateLimiter(rate int, window time.Duration) *RateLimiter {
	rl := &RateLimiter{
		visitors: make(map[string]*visitor),
		rate:     rate,
		window:   window,
	}

	// Limpiar visitantes antiguos cada minuto
	go rl.cleanupVisitors()

	return rl
}

func (rl *RateLimiter) cleanupVisitors() {
	for {
		time.Sleep(time.Minute)
		rl.mu.Lock()
		for ip, v := range rl.visitors {
			if time.Since(v.lastSeen) > rl.window*2 {
				delete(rl.visitors, ip)
			}
		}
		rl.mu.Unlock()
	}
}

// Allow verifica si una IP puede hacer una request.
func (rl *RateLimiter) Allow(ip string) bool {
	rl.mu.Lock()
	defer rl.mu.Unlock()

	v, exists := rl.visitors[ip]
	if !exists {
		rl.visitors[ip] = &visitor{count: 1, lastSeen: time.Now()}
		return true
	}

	// Si pasó la ventana, resetear el contador
	if time.Since(v.lastSeen) > rl.window {
		v.count = 1
		v.lastSeen = time.Now()
		return true
	}

	// Incrementar y verificar límite
	v.count++
	v.lastSeen = time.Now()
	return v.count <= rl.rate
}

// RateLimitMiddleware crea un middleware de Gin para rate limiting.
func RateLimitMiddleware(limiter *RateLimiter) gin.HandlerFunc {
	return func(c *gin.Context) {
		ip := c.ClientIP()
		if !limiter.Allow(ip) {
			c.JSON(http.StatusTooManyRequests, gin.H{
				"error": "Demasiadas solicitudes. Por favor, espera un momento.",
			})
			c.Abort()
			return
		}
		c.Next()
	}
}

// SecurityHeadersMiddleware agrega headers de seguridad a todas las respuestas.
func SecurityHeadersMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		// Prevenir clickjacking
		c.Header("X-Frame-Options", "DENY")
		// Prevenir sniffing de MIME type
		c.Header("X-Content-Type-Options", "nosniff")
		// Política de referrer
		c.Header("Referrer-Policy", "strict-origin-when-cross-origin")
		// Content Security Policy básica
		c.Header("Content-Security-Policy", "default-src 'self'")
		// Permissions Policy (restringe APIs del navegador)
		c.Header("Permissions-Policy", "camera=(), microphone=(), geolocation=()")

		// HSTS — solo en producción (en desarrollo se usa HTTP)
		if gin.Mode() == gin.ReleaseMode {
			c.Header("Strict-Transport-Security", "max-age=31536000; includeSubDomains")
		}

		c.Next()
	}
}

// RequestLoggerMiddleware registra todas las requests con información útil.
func RequestLoggerMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		start := time.Now()
		path := c.Request.URL.Path

		c.Next()

		latency := time.Since(start)
		status := c.Writer.Status()
		clientIP := c.ClientIP()

		// Solo loguear si hay error o es lento (>500ms)
		if status >= 400 || latency > 500*time.Millisecond {
			method := c.Request.Method
			// Log estructurado para producción
			gin.DefaultWriter.Write([]byte(
				"[WARN] " + method + " " + path +
					" | Status: " + http.StatusText(status) +
					" | IP: " + clientIP +
					" | Latency: " + latency.String() + "\n",
			))
		}
	}
}
