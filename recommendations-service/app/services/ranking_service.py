import logging

logger = logging.getLogger(__name__)


class RankingService:
    def __init__(self, model):
        self.model = model

    def rank_candidates(self, user_id: int, candidates: list, features_df):
        """Uses the loaded LightGBM model to score and sort candidates."""
        try:
            scores = self.model.predict(features_df)
        except Exception as e:
            logger.warning("ML Model prediction failed, falling back to heuristic: %s", e)
            scores = [1.0] * len(candidates)

        scored_candidates = list(zip(candidates, scores))
        scored_candidates.sort(key=lambda x: x[1], reverse=True)
        return scored_candidates

