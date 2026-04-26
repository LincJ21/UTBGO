import os
import logging
from redis import Redis
from rq import Worker, Queue, Connection

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("video-worker")

redis_url = os.getenv("REDIS_URL", "redis://localhost:6379/0")
conn = Redis.from_url(redis_url)

if __name__ == '__main__':
    listen = ['video_processing']
    logger.info(f"Starting Video Processing Worker. Listening to queues: {listen}")
    with Connection(conn):
        worker = Worker(map(Queue, listen))
        worker.work()
