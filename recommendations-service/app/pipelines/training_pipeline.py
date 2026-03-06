import pandas as pd
import lightgbm as lgb
from sqlalchemy import create_engine
from app.core.config import settings
import logging
import os
import joblib

logger = logging.getLogger(__name__)

class TrainingPipeline:
    def __init__(self):
        # El pipeline de entrenamiento necesita conectarse al DB de Tracking 
        # (usamos la URL del tracking-service o una variable específica de ETL)
        self.tracking_db_url = os.getenv("TRACKING_DATABASE_URL", "postgresql://tracking_user:tracking_password@localhost:5432/tracking_db")
        self.model_save_path = settings.MODEL_PATH

    def extract_data(self) -> pd.DataFrame:
        """
        Extrae eventos de interacción de la base de datos de Tracking.
        """
        logger.info("Extracting interaction data from Tracking DB...")
        engine = create_engine(self.tracking_db_url)
        query = "SELECT user_id, content_id, event_type, event_value FROM tracking_events"
        return pd.read_sql(query, engine)

    def engineer_features_and_labels(self, df: pd.DataFrame):
        """
        Convierte eventos crudos en un dataset de aprendizaje supervisado.
        Labels (Relevancia):
        - like/bookmark: 3 (Alta)
        - view/comment/share: 1 (Media)
        - unlike: -1 (Baja/Negativa)
        """
        logger.info("Engineering labels and features...")
        
        # Mapeo de relevancia
        relevance_map = {
            'like': 3,
            'bookmark': 3,
            'share': 2,
            'comment': 2,
            'view': 1,
            'search_click': 1,
            'unlike': -1
        }
        
        df['label'] = df['event_type'].map(relevance_map).fillna(0)
        
        # Agregamos features mock (en producción vendrían de content_metrics)
        # Para este ejemplo creamos features sintéticas basadas en ids
        df['feat_user_id'] = df['user_id'] % 100
        df['feat_content_id'] = df['content_id'] % 50
        
        return df

    def run(self):
        """
        Ejecuta el ciclo completo de entrenamiento.
        """
        try:
            # 1. ETL
            raw_data = self.extract_data()
            if raw_data.empty:
                logger.warning("No data found in Tracking DB. Training aborted.")
                return False

            # 2. Preprocessing
            processed_data = self.engineer_features_and_labels(raw_data)
            
            X = processed_data[['feat_user_id', 'feat_content_id']]
            y = processed_data['label']

            # 3. Training (LightGBM Ranker o Regressor)
            logger.info("Starting LightGBM Training...")
            model = lgb.LGBMRegressor(
                n_estimators=100,
                learning_rate=0.1,
                random_state=42
            )
            
            model.fit(X, y)

            # 4. Save Model
            logger.info(f"Saving model to {self.model_save_path}")
            os.makedirs(os.path.dirname(self.model_save_path), exist_ok=True)
            joblib.dump(model, self.model_save_path)
            
            logger.info("Training Pipeline completed successfully.")
            return True

        except Exception as e:
            logger.error(f"Training Pipeline failed: {e}")
            return False

if __name__ == "__main__":
    # Script de ejecución manual
    logging.basicConfig(level=logging.INFO)
    pipeline = TrainingPipeline()
    pipeline.run()

