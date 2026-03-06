from sqlalchemy import Column, Integer, String, Float, DateTime, BigInteger
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.sql import func
from app.database.connection import Base

class TrackingEvent(Base):
    __tablename__ = "tracking_events"

    id = Column(BigInteger, primary_key=True, autoincrement=True)
    user_id = Column(Integer, nullable=False, index=True)
    content_id = Column(Integer, nullable=False, index=True)
    event_type = Column(String(50), nullable=False)
    event_value = Column(Float, default=1.0)
    metadata_col = Column('metadata', JSONB, default=dict) # Alias to avoid reserved word conflicts
    created_at = Column(DateTime(timezone=True), server_default=func.now())
