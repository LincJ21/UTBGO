import redis
from app.core.config import settings

def get_redis():
    """
    Returns a Redis connection with pooling via from_url.
    Handles rediss:// for TLS.
    """
    return redis.Redis.from_url(
        settings.REDIS_URL,
        decode_responses=False,
        socket_timeout=5,
        retry_on_timeout=True
    )
