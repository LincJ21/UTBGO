"""
Inference Pipeline — Orchestrates the recommendation generation process.

Architecture:
  1. Candidate Retrieval (fast, from Redis/DB)
  2. Feature Engineering (build feature matrix from real data)
  3. Model Scoring (LightGBM ranking)
  4. Post-processing (top-N selection)

The LightGBM model is loaded ONCE at module import (singleton) to avoid
disk I/O on every request.
"""

import logging

import redis
from sqlalchemy.orm import Session

from app.core.config import settings
from app.models.lgbm_model import LGBMModel
from app.services.candidate_generation import CandidateGenerationService
from app.services.feature_engineering import FeatureEngineeringService
from app.services.ranking_service import RankingService

logger = logging.getLogger(__name__)

# ---- Singleton: load model ONCE at startup, NOT per-request ----
_model = LGBMModel()
_model_loaded = False
try:
    _model.load(settings.MODEL_PATH)
    _model_loaded = True
    logger.info("LightGBM model loaded successfully from %s", settings.MODEL_PATH)
except Exception as e:
    logger.warning("Could not load LightGBM model from %s: %s. Running in Fallback Mode.", settings.MODEL_PATH, e)


class InferencePipeline:
    def __init__(self, db: Session, cache: redis.Redis):
        self.db = db
        self.cache = cache
        self.candidate_gen = CandidateGenerationService(self.cache, self.db)
        self.feature_eng = FeatureEngineeringService(self.db, self.cache)
        self.ranker = RankingService(_model)

    def run(self, user_id: int, limit: int = 10) -> list[int]:
        # 1. Candidate Retrieval
        candidates = self.candidate_gen.get_candidates(user_id, limit=limit * 5)

        if not candidates:
            logger.info("Cold start for user %d — returning popular items", user_id)
            return self.candidate_gen.get_popular_items(limit)

        # 2. Feature Engineering
        features_df = self.feature_eng.build_features(user_id, candidates)

        # 3. Model Scoring
        if _model_loaded and not features_df.empty:
            ranked_items = self.ranker.rank_candidates(user_id, candidates, features_df)
        else:
            logger.debug("Fallback mode: returning candidates sorted by engagement.")
            ranked_items = [(c, 1.0) for c in candidates]

        # 4. Top-N selection
        return [item_id for item_id, _score in ranked_items[:limit]]

