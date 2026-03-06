from sqlalchemy.orm import Session
from app.models.content_watch_time import ContentWatchTime
import logging

logger = logging.getLogger(__name__)


class WatchTimeRepository:
    def __init__(self, db: Session):
        self.db = db

    def save_watch_time(self, user_id: int, content_id: int, watched_seconds: float):
        """Persists a watch time record to the database."""
        try:
            record = ContentWatchTime(
                user_id=user_id,
                content_id=content_id,
                watched_seconds=watched_seconds,
            )
            self.db.add(record)
            self.db.commit()
            self.db.refresh(record)
            return record
        except Exception as e:
            self.db.rollback()
            logger.error(f"Failed to save watch time: {e}")
            raise

    def get_user_watch_time(self, user_id: int, content_id: int) -> float:
        """Returns total watch time for a user on a specific content."""
        from sqlalchemy import func

        result = self.db.query(
            func.coalesce(func.sum(ContentWatchTime.watched_seconds), 0.0)
        ).filter(
            ContentWatchTime.user_id == user_id,
            ContentWatchTime.content_id == content_id,
        ).scalar()
        return float(result)
