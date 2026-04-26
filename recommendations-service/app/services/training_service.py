import logging
from app.pipelines.training_pipeline import TrainingPipeline

logger = logging.getLogger(__name__)

class TrainingService:
    def __init__(self):
        self.pipeline = TrainingPipeline()

    def train_model(self):
        logger.info("Triggering ML training pipeline...")
        result = self.pipeline.run()
        return result
