import lightgbm as lgb
import os
import joblib
import logging

logger = logging.getLogger(__name__)

class LGBMModel:
    def __init__(self):
        self.model = None

    def load(self, path: str):
        """
        Carga el modelo desde un archivo .pkl o .txt.
        """
        if not os.path.exists(path):
            raise FileNotFoundError(f"Model file not found at {path}")
        
        try:
            # Intentar cargar como joblib (común para sklearn/lgbm wrappers)
            self.model = joblib.load(path)
            logger.info(f"Model loaded successfully from {path} using joblib")
        except Exception:
            try:
                # Intentar cargar como booster nativo de LightGBM
                self.model = lgb.Booster(model_file=path)
                logger.info(f"Model loaded successfully from {path} using lgb.Booster")
            except Exception as e:
                logger.error(f"Failed to load model from {path}: {e}")
                raise e

    def predict(self, features):
        """
        Realiza la predicción. Soporta tanto el Wrapper de Scikit-learn como el Booster nativo.
        """
        if self.model is None:
            raise ValueError("Model not loaded. Call load() before predict().")
        
        try:
            # Si es el wrapper de sklearn
            if hasattr(self.model, 'predict'):
                return self.model.predict(features)
            # Si es el Booster nativo
            return self.model.predict(features)
        except Exception as e:
            logger.error(f"Prediction error: {e}")
            raise e

