import pandas as pd
import lightgbm as lgb
from sqlalchemy import create_engine
from app.core.config import settings
import logging
import os
import joblib
from datetime import datetime
from sklearn.model_selection import train_test_split
from sklearn.metrics import mean_squared_error
import numpy as np
from dotenv import load_dotenv

load_dotenv()

logger = logging.getLogger(__name__)

class TrainingPipeline:
    def __init__(self):
        # Conexión al Postgres (Tracking DB o API DB dependiendo donde vivan las interacciones)
        self.tracking_db_url = os.getenv("DATABASE_URL", "postgresql://utm_user:utm_pass@localhost:5432/utbgo")
        
        # Guardaremos un historial en el directorio base
        self.model_save_dir = os.path.dirname(settings.MODEL_PATH)
        os.makedirs(self.model_save_dir, exist_ok=True)

    def extract_data(self) -> pd.DataFrame:
        """
        Paso 1 (ETL): Extrae eventos de interacción.
        """
        logger.info("Extracting interaction data from Tracking DB...")
        try:
            engine = create_engine(self.tracking_db_url)
            query = "SELECT user_id, content_id, event_type, event_value, created_at FROM tracking_events"
            df = pd.read_sql(query, engine)
            logger.info(f"Loaded {len(df)} tracking events.")
            return df
        except Exception as e:
            logger.error(f"Error connecting to database: {e}")
            return pd.DataFrame()

    def engineer_features_and_labels(self, df: pd.DataFrame) -> pd.DataFrame:
        """
        Paso 2: Transforma crudos a matriz numérica LightGBM.
        """
        logger.info("Engineering labels and features...")
        
        if df.empty:
            return df

        # Mapeo de Relevancia (Target Y)
        relevance_map = {
            'like': 3.0,
            'bookmark': 3.0,
            'share': 2.0,
            'comment': 2.0,
            'view': 1.0,
            'search_click': 1.0,
            'unlike': -1.0
        }
        
        df['label'] = df['event_type'].map(relevance_map).fillna(0.0)
        
        # Features a Nivel Usuario (Agregaciones Históricas)
        user_stats = df.groupby('user_id').agg(
            user_total_events=('event_type', 'count'),
            user_total_likes=('event_type', lambda x: (x == 'like').sum()),
            user_avg_activity=('label', 'mean')
        ).reset_index()

        # Features a Nivel Contenido
        content_stats = df.groupby('content_id').agg(
            content_total_events=('event_type', 'count'),
            content_total_likes=('event_type', lambda x: (x == 'like').sum()),
            content_avg_rating=('label', 'mean')
        ).reset_index()

        # Merge de las agrupaciones con el dataset original
        df = df.merge(user_stats, on='user_id', how='left')
        df = df.merge(content_stats, on='content_id', how='left')

        # Features Contextuales
        df['created_at'] = pd.to_datetime(df['created_at'])
        df['hour_of_day'] = df['created_at'].dt.hour
        df['day_of_week'] = df['created_at'].dt.dayofweek

        # Tratamiento de nulos (si es el primer evento de un user o content)
        df.fillna(0, inplace=True)

        return df

    def run(self) -> dict:
        """
        Paso 3, 4 y 5: Ciclo Maestro (Extract, Preprocess, Split, Train, Evaluate, y VERSIONADO).
        """
        try:
            # 1. ETL
            raw_data = self.extract_data()
            if raw_data.empty:
                logger.warning("No data found to train on.")
                return {"status": "error", "message": "No data in database"}

            # 2. Preprocessing
            processed_data = self.engineer_features_and_labels(raw_data)
            
            features = [
                'user_total_events', 'user_total_likes', 'user_avg_activity',
                'content_total_events', 'content_total_likes', 'content_avg_rating',
                'hour_of_day', 'day_of_week'
            ]
            
            X = processed_data[features]
            y = processed_data['label']

            # 3. Train / Test Split
            X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)

            # 4. Training
            logger.info("Starting LightGBM Training...")
            model = lgb.LGBMRegressor(
                n_estimators=100,
                learning_rate=0.05,
                max_depth=6,
                random_state=42
            )
            
            model.fit(X_train, y_train)

            # 5. Evaluation
            predictions = model.predict(X_test)
            rmse = float(np.sqrt(mean_squared_error(y_test, predictions)))
            logger.info(f"Model Training completed. Validation RMSE: {rmse:.4f}")

            # 6. Save Versioned Model (Historial de Versiones)
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            versioned_filename = f"model_v{timestamp}.lgb"
            save_path = os.path.join(self.model_save_dir, versioned_filename)
            
            joblib.dump(model, save_path)
            logger.info(f"Versioned model saved successfully as: {versioned_filename}")
            
            # También guardamos en 'model.lgb' (el puntero persistente para el motor de inferencia)
            latest_path = os.path.join(self.model_save_dir, "model.lgb")
            joblib.dump(model, latest_path)

            return {
                "status": "success",
                "rmse": rmse,
                "model_version": versioned_filename,
                "dataset_size": len(X)
            }

        except Exception as e:
            logger.error(f"Training Pipeline failed: {e}")
            return {"status": "error", "message": str(e)}

if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    pipeline = TrainingPipeline()
    result = pipeline.run()
    if 'rmse' in result:
        print(f"Training Sucessful! RMSE: {result['rmse']}")
    else:
        print(f"Failed: {result.get('message', 'Unknown Error')}")

