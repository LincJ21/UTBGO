"""
UTBGO Video Processing Worker

Continuously polls a Redis queue for video transcoding tasks and processes
them using FFmpeg via the tasks module. Uses a simple lpop-based polling
loop instead of RQ's built-in worker to ensure compatibility with the
JSON payloads produced by the Go API service.

Architecture:
    Go API --LPUSH JSON--> Redis Queue --LPOP--> This Worker --> FFmpeg --> Cloudinary

Features:
    - Graceful shutdown on SIGTERM/SIGINT signals
    - Structured logging for monitoring
    - Configurable queue name via REDIS_QUEUE_NAME env var
    - Automatic reconnection on transient Redis failures
"""

import os
import sys
import json
import time
import signal
import logging

from redis import Redis
from tasks import process_video_hls

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

POLL_INTERVAL_SECONDS = 2
"""How long to sleep between polls when the queue is empty."""

RECONNECT_DELAY_SECONDS = 5
"""How long to wait before retrying after a Redis connection failure."""

REDIS_QUEUE_PREFIX = "rq:queue:"
"""Prefix applied to the logical queue name to form the full Redis key."""

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s | %(name)-20s | %(levelname)-7s | %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)
logger = logging.getLogger("video-worker")

# ---------------------------------------------------------------------------
# Configuration (from environment)
# ---------------------------------------------------------------------------

REDIS_URL = os.getenv("REDIS_URL", "redis://localhost:6379/0")
QUEUE_NAME = os.getenv("REDIS_QUEUE_NAME", "video_processing")

# ---------------------------------------------------------------------------
# Graceful shutdown
# ---------------------------------------------------------------------------

_running = True


def _handle_shutdown(signum, _frame):
    """Set the shutdown flag so the main loop exits cleanly."""
    global _running
    sig_name = signal.Signals(signum).name
    logger.info("Received %s — shutting down gracefully...", sig_name)
    _running = False


# ---------------------------------------------------------------------------
# Main loop
# ---------------------------------------------------------------------------


def _process_message(msg_str: str) -> None:
    """Parse a JSON message and delegate to the HLS pipeline."""
    payload = json.loads(msg_str)
    video_id = payload.get("video_id")
    source_url = payload.get("source_url")

    if not video_id or not source_url:
        logger.error("Invalid payload (missing video_id or source_url): %s", payload)
        return

    logger.info("Starting HLS compression for Video ID: %s", video_id)
    process_video_hls(str(video_id), str(source_url))
    logger.info("Finished processing Video ID: %s", video_id)


def main() -> None:
    """Entry-point: connect to Redis and poll the queue forever."""
    signal.signal(signal.SIGTERM, _handle_shutdown)
    signal.signal(signal.SIGINT, _handle_shutdown)

    full_queue_key = f"{REDIS_QUEUE_PREFIX}{QUEUE_NAME}"

    logger.info("=" * 50)
    logger.info("UTBGO Video Processing Worker")
    logger.info("Queue key : %s", full_queue_key)
    logger.info("Redis     : %s...", REDIS_URL[:35])
    logger.info("=" * 50)

    # --- Connect to Redis ---------------------------------------------------
    try:
        conn = Redis.from_url(REDIS_URL)
        conn.ping()
        logger.info("Connected to Redis successfully")
    except Exception as exc:
        logger.error("Failed to connect to Redis: %s", exc)
        sys.exit(1)

    logger.info("Listening for tasks on '%s'...", full_queue_key)

    # --- Poll loop ----------------------------------------------------------
    while _running:
        try:
            raw_msg = conn.lpop(full_queue_key)

            if raw_msg is None:
                time.sleep(POLL_INTERVAL_SECONDS)
                continue

            msg_str = raw_msg.decode("utf-8")
            logger.info("Received message: %s", msg_str)

            try:
                _process_message(msg_str)
            except json.JSONDecodeError:
                logger.error("Malformed JSON, skipping: %s", msg_str)
            except Exception as exc:
                logger.error(
                    "Error processing task: %s", exc, exc_info=True
                )

        except Exception as exc:
            if _running:
                logger.error(
                    "Redis connection error: %s — retrying in %ds",
                    exc,
                    RECONNECT_DELAY_SECONDS,
                )
                time.sleep(RECONNECT_DELAY_SECONDS)

    logger.info("Worker stopped cleanly.")


if __name__ == "__main__":
    main()
