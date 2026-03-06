from pydantic_settings import BaseSettings, SettingsConfigDict
from typing import Optional
from dotenv import load_dotenv
import os

# Force load .env from the root of the recommendations-service
env_path = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(__file__))), '.env')
load_dotenv(dotenv_path=env_path, override=True)

class Settings(BaseSettings):
    PROJECT_NAME: str = "Recommendation Service"
    VERSION: str = "1.0.0"
    API_V1_STR: str = "/api/v1"
    
    DATABASE_URL: Optional[str] = (os.getenv("DATABASE_URL") or os.getenv("DB_CONNECTION_STRING") or "").strip().strip("'").strip('"')
    REDIS_HOST: str = os.getenv("REDIS_HOST", "localhost").strip().strip("'").strip('"')
    REDIS_PORT: int = int(str(os.getenv("REDIS_PORT", 6379)).strip().strip("'").strip('"'))
    REDIS_URL: str = os.getenv("REDIS_URL", f"redis://{REDIS_HOST}:{REDIS_PORT}").strip().strip("'").strip('"')
    API_KEY: str = (os.getenv("RECOMMENDATIONS_API_KEY") or os.getenv("API_KEY") or "super-secret-recs-key").strip().strip("'").strip('"')
    CORS_ORIGINS: list[str] = ["http://localhost", "http://localhost:8000", "http://localhost:3000"]
    
    MODEL_PATH: str = os.getenv("MODEL_PATH", "app/models_storage/lgbm_model.pkl").strip().strip("'").strip('"')
    
    model_config = SettingsConfigDict(
        env_file=".env",
        case_sensitive=True,
        extra='ignore'
    )

settings = Settings()
