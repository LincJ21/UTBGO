import redis
from app.core.config import settings
import logging

logger = logging.getLogger(__name__)

# Connection pool for Redis for high concurrency via URL (supports rediss://)
redis_client = redis.Redis.from_url(
    settings.REDIS_URL,
    decode_responses=True,
    max_connections=50
)

def get_redis():
    try:
        return redis_client
    except redis.ConnectionError as e:
        logger.error(f"Redis connection error: {e}")
        raise
