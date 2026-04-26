import logging
from apscheduler.schedulers.background import BackgroundScheduler
from apscheduler.triggers.cron import CronTrigger
from app.services.training_service import TrainingService

logger = logging.getLogger(__name__)

def run_weekly_training():
    """Wrapper function to execute the ML training."""
    logger.info("=== Cron Job Triggered: Weekly ML Retraining ===")
    try:
        svc = TrainingService()
        svc.train_model()
        logger.info("=== Cron Job Finished: Weekly ML Retraining ===")
    except Exception as e:
        logger.error(f"Cron Job failed during ML Retraining: {e}")

# Global scheduler instance
scheduler = BackgroundScheduler()

def start_scheduler():
    """
    Initializes and starts the background scheduler.
    Scheduled to run every Sunday at 03:00 AM.
    """
    logger.info("Initializing APScheduler...")
    
    # Run every Sunday at 3:00 AM (production best practice)
    trigger = CronTrigger(day_of_week="sun", hour=3, minute=0)
    
    scheduler.add_job(
        run_weekly_training,
        trigger=trigger,
        id="weekly_ml_retraining",
        name="Retrain LightGBM Model",
        replace_existing=True
    )
    
    scheduler.start()
    logger.info("APScheduler started successfully. Next run scheduled.")

def shutdown_scheduler():
    """Gracefully shuts down the scheduler."""
    logger.info("Shutting down APScheduler...")
    if scheduler.running:
        scheduler.shutdown()
        logger.info("APScheduler shutdown complete.")
