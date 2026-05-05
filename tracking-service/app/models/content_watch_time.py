from sqlalchemy import Column, Integer, Float, DateTime, BigInteger
from sqlalchemy.sql import func
from app.database.connection import Base

class ContentWatchTime(Base):
    __tablename__ = "content_watch_time"

    id = Column(BigInteger, primary_key=True, autoincrement=True)
    user_id = Column(Integer, nullable=False, index=True)
    content_id = Column(Integer, nullable=False, index=True)
    watched_seconds = Column(Float, nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
