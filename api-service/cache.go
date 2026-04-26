package main

import (
	"context"
	"encoding/json"
	"fmt"
	"os"
	"time"

	"github.com/redis/go-redis/v9"
)

// =============================================================================
// Cache — Sistema de caché con Redis para UTBGO
// =============================================================================
// Cachea las consultas más frecuentes (feed, perfiles) para reducir carga en
// PostgreSQL y mejorar tiempos de respuesta. Diseñado para ~8000+ usuarios.
//
// Estrategia de invalidación:
//   - Feed: se invalida al crear un video nuevo (TTL: 5 min)
//   - Perfiles: se invalida al actualizar perfil/avatar (TTL: 10 min)
//   - Búsquedas: TTL corto de 2 min (no se invalida explícitamente)
//
// Variables de entorno requeridas:
//   - REDIS_URL: URL de conexión Redis (ej: redis://default:pass@host:6379)
// =============================================================================

// CacheService gestiona el caché con Redis.
// Envuelve el cliente de Redis con métodos tipados para cada entidad.
type CacheService struct {
	client *redis.Client
}

// Prefijos de claves para evitar colisiones y facilitar invalidación por patrón.
const (
	cacheKeyPrefixFeed     = "feed:"     // feed:page:1, feed:page:2
	cacheKeyPrefixProfile  = "profile:"  // profile:user:42
	cacheKeyPrefixSearch   = "search:"   // search:q:flutter
	cacheKeyPrefixComments = "comments:" // comments:video:15

	cacheTTLFeed     = 5 * time.Minute  // El feed cambia con cada video nuevo
	cacheTTLProfile  = 10 * time.Minute // Los perfiles cambian poco
	cacheTTLSearch   = 2 * time.Minute  // Búsquedas efímeras
	cacheTTLComments = 1 * time.Minute  // Comentarios cambian frecuentemente
)

// Cache es la instancia global del servicio de caché.
// Es nil si Redis no está configurado (fallback a sin caché).
var Cache *CacheService

// NewCacheService crea una nueva instancia de CacheService.
// Parsea la REDIS_URL y verifica la conexión con un PING.
func NewCacheService() (*CacheService, error) {
	redisURL := os.Getenv("REDIS_URL")
	if redisURL == "" {
		return nil, fmt.Errorf("REDIS_URL no está configurada")
	}

	opts, err := redis.ParseURL(redisURL)
	if err != nil {
		return nil, fmt.Errorf("URL de Redis inválida: %w", err)
	}

	// Configuración del pool de conexiones Redis
	opts.PoolSize = 20    // Conexiones concurrentes máximas
	opts.MinIdleConns = 5 // Mantener 5 conexiones listas
	opts.ReadTimeout = 3 * time.Second
	opts.WriteTimeout = 3 * time.Second
	opts.DialTimeout = 5 * time.Second

	client := redis.NewClient(opts)

	// Verificar conexión
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	if err := client.Ping(ctx).Err(); err != nil {
		return nil, fmt.Errorf("no se pudo conectar a Redis: %w", err)
	}

	return &CacheService{client: client}, nil
}

// Close cierra la conexión con Redis.
func (cs *CacheService) Close() error {
	return cs.client.Close()
}

// --- Operaciones genéricas de caché ---

// Get obtiene un valor del caché y lo deserializa en dest.
// Retorna false si la clave no existe (cache miss).
func (cs *CacheService) Get(ctx context.Context, key string, dest interface{}) (bool, error) {
	val, err := cs.client.Get(ctx, key).Result()
	if err == redis.Nil {
		return false, nil // Cache miss
	}
	if err != nil {
		return false, err
	}

	if err := json.Unmarshal([]byte(val), dest); err != nil {
		return false, fmt.Errorf("error deserializando caché: %w", err)
	}
	return true, nil
}

// Set guarda un valor en el caché con TTL.
func (cs *CacheService) Set(ctx context.Context, key string, value interface{}, ttl time.Duration) error {
	data, err := json.Marshal(value)
	if err != nil {
		return fmt.Errorf("error serializando para caché: %w", err)
	}
	return cs.client.Set(ctx, key, data, ttl).Err()
}

// Delete elimina una o más claves del caché.
func (cs *CacheService) Delete(ctx context.Context, keys ...string) error {
	return cs.client.Del(ctx, keys...).Err()
}

// SetNX guarda un valor solo si la clave NO existe (atómico).
// Retorna true si la clave fue creada, false si ya existía.
// Útil para debounce y rate limiting por clave.
func (cs *CacheService) SetNX(ctx context.Context, key string, value interface{}, ttl time.Duration) (bool, error) {
	return cs.client.SetNX(ctx, key, value, ttl).Result()
}

// DeleteByPattern elimina todas las claves que coincidan con un patrón.
// Usa SCAN para no bloquear Redis (a diferencia de KEYS).
// Ejemplo: DeleteByPattern(ctx, "feed:*") elimina todo el caché de feed.
func (cs *CacheService) DeleteByPattern(ctx context.Context, pattern string) error {
	var cursor uint64
	for {
		keys, nextCursor, err := cs.client.Scan(ctx, cursor, pattern, 100).Result()
		if err != nil {
			return err
		}
		if len(keys) > 0 {
			if err := cs.client.Del(ctx, keys...).Err(); err != nil {
				return err
			}
		}
		cursor = nextCursor
		if cursor == 0 {
			break
		}
	}
	return nil
}

// --- Métodos específicos por entidad ---

// GetFeed obtiene el feed cacheado para una página específica.
func (cs *CacheService) GetFeed(ctx context.Context, page int) (interface{}, bool) {
	key := fmt.Sprintf("%spage:%d", cacheKeyPrefixFeed, page)
	var result interface{}
	found, err := cs.Get(ctx, key, &result)
	if err != nil {
		Logger.Warn("Error leyendo caché de feed", "error", err)
		return nil, false
	}
	return result, found
}

// SetFeed guarda el feed en caché.
func (cs *CacheService) SetFeed(ctx context.Context, page int, data interface{}) {
	key := fmt.Sprintf("%spage:%d", cacheKeyPrefixFeed, page)
	if err := cs.Set(ctx, key, data, cacheTTLFeed); err != nil {
		Logger.Warn("Error guardando caché de feed", "error", err)
	}
}

// InvalidateFeed elimina todo el caché del feed.
// Llamar al crear, eliminar, o cambiar un video.
func (cs *CacheService) InvalidateFeed(ctx context.Context) {
	if err := cs.DeleteByPattern(ctx, cacheKeyPrefixFeed+"*"); err != nil {
		Logger.Warn("Error invalidando caché de feed", "error", err)
	}
	Logger.Info("Caché de feed invalidado")
}

// GetProfile obtiene el perfil cacheado de un usuario.
func (cs *CacheService) GetProfile(ctx context.Context, userID int) (interface{}, bool) {
	key := fmt.Sprintf("%suser:%d", cacheKeyPrefixProfile, userID)
	var result interface{}
	found, err := cs.Get(ctx, key, &result)
	if err != nil {
		Logger.Warn("Error leyendo caché de perfil", "error", err, "user_id", userID)
		return nil, false
	}
	return result, found
}

// SetProfile guarda el perfil de un usuario en caché.
func (cs *CacheService) SetProfile(ctx context.Context, userID int, data interface{}) {
	key := fmt.Sprintf("%suser:%d", cacheKeyPrefixProfile, userID)
	if err := cs.Set(ctx, key, data, cacheTTLProfile); err != nil {
		Logger.Warn("Error guardando caché de perfil", "error", err, "user_id", userID)
	}
}

// InvalidateProfile elimina el caché de un usuario específico.
// Llamar al actualizar perfil o avatar.
func (cs *CacheService) InvalidateProfile(ctx context.Context, userID int) {
	key := fmt.Sprintf("%suser:%d", cacheKeyPrefixProfile, userID)
	if err := cs.Delete(ctx, key); err != nil {
		Logger.Warn("Error invalidando caché de perfil", "error", err, "user_id", userID)
	}
}

// GetSearch obtiene resultados de búsqueda cacheados.
func (cs *CacheService) GetSearch(ctx context.Context, query string) (interface{}, bool) {
	key := fmt.Sprintf("%sq:%s", cacheKeyPrefixSearch, query)
	var result interface{}
	found, err := cs.Get(ctx, key, &result)
	if err != nil {
		return nil, false
	}
	return result, found
}

// SetSearch guarda resultados de búsqueda en caché.
func (cs *CacheService) SetSearch(ctx context.Context, query string, data interface{}) {
	key := fmt.Sprintf("%sq:%s", cacheKeyPrefixSearch, query)
	if err := cs.Set(ctx, key, data, cacheTTLSearch); err != nil {
		Logger.Warn("Error guardando caché de búsqueda", "error", err)
	}
}

// GetComments obtiene comentarios cacheados de un video.
func (cs *CacheService) GetComments(ctx context.Context, videoID int) (interface{}, bool) {
	key := fmt.Sprintf("%svideo:%d", cacheKeyPrefixComments, videoID)
	var result interface{}
	found, err := cs.Get(ctx, key, &result)
	if err != nil {
		return nil, false
	}
	return result, found
}

// SetComments guarda comentarios en caché.
func (cs *CacheService) SetComments(ctx context.Context, videoID int, data interface{}) {
	key := fmt.Sprintf("%svideo:%d", cacheKeyPrefixComments, videoID)
	if err := cs.Set(ctx, key, data, cacheTTLComments); err != nil {
		Logger.Warn("Error guardando caché de comentarios", "error", err)
	}
}

// InvalidateComments elimina el caché de comentarios de un video.
func (cs *CacheService) InvalidateComments(ctx context.Context, videoID int) {
	key := fmt.Sprintf("%svideo:%d", cacheKeyPrefixComments, videoID)
	if err := cs.Delete(ctx, key); err != nil {
		Logger.Warn("Error invalidando caché de comentarios", "error", err)
	}
}
