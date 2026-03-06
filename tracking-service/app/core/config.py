from pydantic_settings import BaseSettings, SettingsConfigDict
from typing import Optional
from dotenv import load_dotenv
import os

# Force load .env from the root of the tracking-service
env_path = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(__file__))), '.env')
load_dotenv(dotenv_path=env_path, override=True)

class Settings(BaseSettings):
    PROJECT_NAME: str = "Tracking Service"
    VERSION: str = "1.0.0"
    API_V1_STR: str = "/api/v1"
    
    DATABASE_URL: Optional[str] = os.getenv("DATABASE_URL", "").strip().strip("'").strip('"')
    API_KEY: str = os.getenv("API_KEY", "super-secret-tracking-key").strip().strip("'").strip('"')
    CORS_ORIGINS: list[str] = ["http://localhost", "http://localhost:8000", "http://localhost:3000"]
    
    REDIS_HOST: str = os.getenv("REDIS_HOST", "localhost").strip().strip("'").strip('"')
    REDIS_PORT: int = int(str(os.getenv("REDIS_PORT", 6379)).strip().strip("'").strip('"'))
    REDIS_URL: str = os.getenv("REDIS_URL", f"redis://{REDIS_HOST}:{REDIS_PORT}").strip().strip("'").strip('"')
    REDIS_QUEUE_NAME: str = os.getenv("REDIS_QUEUE_NAME", "tracking:event_queue").strip().strip("'").strip('"')

    model_config = SettingsConfigDict(
        env_file=".env",
        case_sensitive=True,
        extra='ignore'
    )

settings = Settings()
