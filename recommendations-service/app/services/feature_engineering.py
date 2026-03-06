import pandas as pd
from sqlalchemy.orm import Session
from datetime import datetime
import redis
import logging

from app.repositories.content_repo import ContentRepository
from app.repositories.user_repo import UserRepository

logger = logging.getLogger(__name__)


class FeatureEngineeringService:
    def __init__(self, db: Session, cache: redis.Redis):
        self.db = db
        self.cache = cache
        self.content_repo = ContentRepository(db)
        self.user_repo = UserRepository(db)

    def build_features(self, user_id: int, candidates: list[int]) -> pd.DataFrame:
        """
        Builds the feature DataFrame for the LightGBM model.
        Combines user-level features with content-level features from real data.
        """
        if not candidates:
            return pd.DataFrame()

        # 1. Get user-level features
        user_features = self.user_repo.get_user_feature_vector(user_id)

        # 2. Get content-level features for all candidates
        content_features_list = self.content_repo.get_content_features(candidates)

        # Build a lookup by content_id
        content_features_map = {
            item["content_id"]: item for item in content_features_list
        }

        # 3. Build combined feature rows
        now = datetime.now()
        data = []
        for item_id in candidates:
            content_feat = content_features_map.get(item_id, {})

            row = {
                # Identifiers
                "user_id": user_id,
                "item_id": item_id,

                # User features
                "user_total_events": user_features.get("total_events", 0),
                "user_unique_content": user_features.get("unique_content_viewed", 0),
                "user_likes_given": user_features.get("total_likes_given", 0),
                "user_bookmarks_given": user_features.get("total_bookmarks_given", 0),
                "user_comments_given": user_features.get("total_comments_given", 0),
                "user_avg_event_value": user_features.get("avg_event_value", 0.0),

                # Content features
                "item_total_views": content_feat.get("total_views", 0),
                "item_total_likes": content_feat.get("total_likes", 0),
                "item_total_bookmarks": content_feat.get("total_bookmarks", 0),
                "item_total_comments": content_feat.get("total_comments", 0),
                "item_engagement_rate": content_feat.get("engagement_rate", 0.0),
                "item_avg_watch_time": content_feat.get("avg_watch_time", 0.0),
                "item_completion_rate": content_feat.get("completion_rate", 0.0),

                # Context features
                "hour_of_day": now.hour,
                "day_of_week": now.weekday(),
            }
            data.append(row)

        df = pd.DataFrame(data)
        logger.debug(f"Built feature DataFrame: {df.shape[0]} rows x {df.shape[1]} cols")
        return df
