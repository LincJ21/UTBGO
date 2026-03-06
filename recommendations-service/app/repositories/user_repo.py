from sqlalchemy.orm import Session
from sqlalchemy import text
import logging

logger = logging.getLogger(__name__)


class UserRepository:
    """Reads aggregated user preference data from the shared Postgres database."""

    def __init__(self, db: Session):
        self.db = db

    def get_user_feature_vector(self, user_id: int) -> dict:
        """
        Builds a user-level feature vector from their tracking history.
        Returns aggregated stats about the user's behavior.
        """
        result = self.db.execute(text("""
            SELECT
                COUNT(*) AS total_events,
                COUNT(DISTINCT content_id) AS unique_content_viewed,
                COUNT(*) FILTER (WHERE event_type = 'like') AS total_likes_given,
                COUNT(*) FILTER (WHERE event_type = 'bookmark') AS total_bookmarks_given,
                COUNT(*) FILTER (WHERE event_type = 'comment') AS total_comments_given,
                COUNT(*) FILTER (WHERE event_type = 'share') AS total_shares_given,
                COALESCE(AVG(event_value), 0) AS avg_event_value
            FROM tracking_events
            WHERE user_id = :user_id
        """), {"user_id": user_id})

        row = result.fetchone()
        if row is None:
            return {
                "total_events": 0,
                "unique_content_viewed": 0,
                "total_likes_given": 0,
                "total_bookmarks_given": 0,
                "total_comments_given": 0,
                "total_shares_given": 0,
                "avg_event_value": 0.0,
            }

        return dict(row._mapping)
