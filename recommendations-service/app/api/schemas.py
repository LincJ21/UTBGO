from pydantic import BaseModel, Field
from typing import List


class RecommendationRequest(BaseModel):
    user_id: int = Field(..., gt=0, description="User ID must be positive")
    limit: int = Field(default=10, ge=1, le=100, description="Max 100 recommendations per request")


class RecommendationResponse(BaseModel):
    user_id: int
    recommendations: List[int]
