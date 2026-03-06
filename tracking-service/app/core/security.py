import hmac
import logging

from fastapi import Security, HTTPException, status
from fastapi.security import APIKeyHeader
from app.core.config import settings

logger = logging.getLogger(__name__)

# Basic API Key Auth for Server-to-Server
API_KEY_NAME = "X-API-Key"
api_key_header = APIKeyHeader(name=API_KEY_NAME, auto_error=False)


async def verify_api_key(api_key: str = Security(api_key_header)):
    """
    Validates the API key using timing-safe comparison to prevent
    timing attacks (OWASP recommendation).
    """
    expected_api_key = getattr(settings, "API_KEY", None)

    if not expected_api_key or not api_key:
        logger.warning("Unauthorized access attempt: missing API Key")
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Could not validate credentials",
        )

    # hmac.compare_digest prevents timing-based side-channel attacks
    if not hmac.compare_digest(api_key.encode(), expected_api_key.encode()):
        logger.warning("Unauthorized access attempt: invalid API Key")
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Could not validate credentials",
        )

    return api_key
