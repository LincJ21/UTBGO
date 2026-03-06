import logging
from app.pipelines.training_pipeline import TrainingPipeline
import sys

# Configurar logging para ver el progreso en consola
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)

logger = logging.getLogger("TrainRunner")

def main():
    logger.info("--- Iniciando Proceso de Re-entrenamiento de Modelo ---")
    pipeline = TrainingPipeline()
    success = pipeline.run()
    
    if success:
        logger.info("✔ Modelo entrenado y guardado correctamente.")
        sys.exit(0)
    else:
        logger.error("❌ El entrenamiento falló. Revisa los logs anteriores.")
        sys.exit(1)

if __name__ == "__main__":
    main()
