from sqlalchemy import create_engine
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker
from app.core.config import settings

DATABASE_URL = settings.DATABASE_URL or "postgresql://user:pass@localhost/tracking_db"

# Pooling optimization for high concurrency
engine = create_engine(
    DATABASE_URL,
    pool_size=20,          # Connections kept open
    max_overflow=10,       # Extra connections allowed during spikes
    pool_timeout=30,       # Wait time before failing
    pool_pre_ping=True,    # Verify connection health before usage
)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

Base = declarative_base()

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
