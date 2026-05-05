from sqlalchemy.orm import Session
from sqlalchemy import text
import logging

logger = logging.getLogger(__name__)

# Mapping from event_type to the column to increment in content_metrics
EVENT_TO_METRIC_COLUMN = {
    "view": "total_views",
    "like": "total_likes",
    "bookmark": "total_bookmarks",
    "share": "total_shares",
    "comment": "total_comments",
}

# Events that decrement (undo actions)
EVENT_DECREMENT = {
    "unlike": "total_likes",
    "unbookmark": "total_bookmarks",
}


def update_content_metrics(db: Session, content_id: int, event_type: str):
    """
    Updates the aggregated content_metrics table after a tracking event.
    Uses UPSERT (INSERT ... ON CONFLICT) to handle new content gracefully.
    """
    increment_col = EVENT_TO_METRIC_COLUMN.get(event_type)
    decrement_col = EVENT_DECREMENT.get(event_type)

    if not increment_col and not decrement_col:
        return  # Event type doesn't affect metrics (e.g. search_click)

    if increment_col:
        db.execute(text("""
            INSERT INTO content_metrics (content_id, {col}, updated_at)
            VALUES (:content_id, 1, NOW())
            ON CONFLICT (content_id)
            DO UPDATE SET
                {col} = content_metrics.{col} + 1,
                updated_at = NOW()
        """.format(col=increment_col)), {"content_id": content_id})

    elif decrement_col:
        db.execute(text("""
            UPDATE content_metrics
            SET {col} = GREATEST(0, {col} - 1),
                updated_at = NOW()
            WHERE content_id = :content_id
        """.format(col=decrement_col)), {"content_id": content_id})

    # Recalculate engagement_rate
    db.execute(text("""
        UPDATE content_metrics
        SET engagement_rate = CASE
            WHEN total_views = 0 THEN 0
            ELSE (total_likes + total_bookmarks + total_comments + total_shares)::FLOAT / total_views
        END,
        updated_at = NOW()
        WHERE content_id = :content_id
    """), {"content_id": content_id})

    logger.debug(f"Metrics updated for content {content_id} (event: {event_type})")
