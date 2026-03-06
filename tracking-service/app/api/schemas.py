from pydantic import BaseModel, Field
from datetime import datetime
from typing import Optional, Dict, Any

class TrackingEventBase(BaseModel):
    user_id: int = Field(..., gt=0, description="User ID must be positive")
    content_id: int = Field(..., gt=0, description="Content ID must be positive")
    event_type: str = Field(
        ...,
        description="E.g., view, like, unlike, share, comment",
        pattern=r"^(view|like|unlike|bookmark|unbookmark|share|comment|search_click)$",
    )
    event_value: float = Field(default=1.0, ge=0, le=86400, description="Numeric value, max 24h in seconds")
    metadata: Optional[Dict[str, Any]] = Field(default_factory=dict, max_length=10)

class TrackingEventCreate(TrackingEventBase):
    pass

class TrackingEventResponse(BaseModel):
    status: str
    message: str


class WatchTimeCreate(BaseModel):
    user_id: int
    content_id: int
    watched_seconds: float = Field(..., gt=0, description="Seconds of content watched")


class WatchTimeResponse(BaseModel):
    status: str
    message: str
