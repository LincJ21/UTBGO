import logging

from sqlalchemy.orm import Session

from app.api.schemas import TrackingEventCreate
from app.models.tracking_event import TrackingEvent

logger = logging.getLogger(__name__)


class TrackingRepository:
    """Persists tracking events. Does NOT own the transaction — caller must commit."""

    def __init__(self, db: Session):
        self.db = db

    def save_event(self, event_data: TrackingEventCreate) -> TrackingEvent:
        db_event = TrackingEvent(
            user_id=event_data.user_id,
            content_id=event_data.content_id,
            event_type=event_data.event_type,
            event_value=event_data.event_value,
            metadata_col=event_data.metadata,
        )
        self.db.add(db_event)
        self.db.flush()  # Assigns PK without committing
        return db_event
