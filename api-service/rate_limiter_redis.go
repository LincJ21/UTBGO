package main

import (
	"context"
	"fmt"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/redis/go-redis/v9"
)

// =============================================================================
// RedisRateLimiter — Rate limiting distribuido con Redis
// =============================================================================
// A diferencia del rate limiter in-memory (middleware.go), este funciona
// correctamente con múltiples instancias del servidor (horizontal scaling).
//
// Usa el algoritmo "fixed window counter" con Redis INCR + EXPIRE:
//   - Cada IP tiene una clave con TTL = ventana de tiempo
//   - INCR atómico incrementa el contador
//   - Si el contador excede el límite, la petición se rechaza
//
// Ventajas sobre in-memory:
//   - Funciona con 2+ instancias del servidor
//   - Sobrevive reinicios del servidor
//   - Sin goroutine de limpieza (Redis maneja TTL)
//   - Sin mutex/locks (Redis es single-threaded)
// =============================================================================

// RedisRateLimiter implementa rate limiting distribuido usando Redis.
type RedisRateLimiter struct {
	client *redis.Client
	rate   int           // Máximo de peticiones por ventana
	window time.Duration // Duración de la ventana
	prefix string        // Prefijo de clave Redis
}

// NewRedisRateLimiter crea un rate limiter distribuido.
// Reutiliza la conexión Redis del CacheService.
func NewRedisRateLimiter(client *redis.Client, rate int, window time.Duration) *RedisRateLimiter {
	return &RedisRateLimiter{
		client: client,
		rate:   rate,
		window: window,
		prefix: "ratelimit:",
	}
}

// Allow verifica si una IP puede hacer una petición.
// Usa INCR atómico + EXPIRE para implementar fixed window counter.
// Retorna (permitido, peticiones restantes, tiempo hasta reset).
func (rl *RedisRateLimiter) Allow(ctx context.Context, ip string) (bool, int, time.Duration) {
	key := fmt.Sprintf("%s%s", rl.prefix, ip)

	// Pipeline para reducir round-trips a Redis
	pipe := rl.client.Pipeline()
	incrCmd := pipe.Incr(ctx, key)
	pipe.Expire(ctx, key, rl.window) // Solo aplica si la clave es nueva
	ttlCmd := pipe.TTL(ctx, key)

	_, err := pipe.Exec(ctx)
	if err != nil {
		// Si Redis falla, permitir la petición (fail-open)
		Logger.Warn("Redis rate limiter error, permitiendo petición", "error", err, "ip", ip)
		return true, rl.rate, rl.window
	}

	count := int(incrCmd.Val())
	ttl := ttlCmd.Val()

	// Si es la primera petición, asegurar que el TTL se aplique
	if count == 1 {
		rl.client.Expire(ctx, key, rl.window)
		ttl = rl.window
	}

	remaining := rl.rate - count
	if remaining < 0 {
		remaining = 0
	}

	return count <= rl.rate, remaining, ttl
}

// RedisRateLimitMiddleware crea un middleware de Gin para rate limiting con Redis.
// Agrega headers estándar de rate limiting en las respuestas:
//   - X-RateLimit-Limit: máximo de peticiones por ventana
//   - X-RateLimit-Remaining: peticiones restantes
//   - X-RateLimit-Reset: segundos hasta que se resetee la ventana
//   - Retry-After: segundos hasta que pueda reintentar (solo en 429)
func RedisRateLimitMiddleware(rl *RedisRateLimiter) gin.HandlerFunc {
	return func(c *gin.Context) {
		ip := c.ClientIP()
		allowed, remaining, ttl := rl.Allow(c.Request.Context(), ip)

		// Agregar headers de rate limiting (RFC 6585)
		c.Header("X-RateLimit-Limit", fmt.Sprintf("%d", rl.rate))
		c.Header("X-RateLimit-Remaining", fmt.Sprintf("%d", remaining))
		c.Header("X-RateLimit-Reset", fmt.Sprintf("%d", int(ttl.Seconds())))

		if !allowed {
			c.Header("Retry-After", fmt.Sprintf("%d", int(ttl.Seconds())))
			c.JSON(http.StatusTooManyRequests, gin.H{
				"error":       "Demasiadas solicitudes. Por favor, espera un momento.",
				"retry_after": int(ttl.Seconds()),
			})
			c.Abort()
			return
		}

		c.Next()
	}
}
