"""
Video HLS Processing Tasks

This module handles the asynchronous transcoding of uploaded videos
into HLS (HTTP Live Streaming) format using FFmpeg.

Architecture:
    Go API → Redis Queue → This Worker → Cloudinary → Go API (callback)

The worker downloads the original MP4 from Cloudinary, transcodes it
into adaptive HLS segments (.ts) with a master playlist (.m3u8),
uploads the results back to Cloudinary, and notifies the Go API
that the video is ready for streaming.
"""

import os
import glob
import tempfile
import logging
import requests
import ffmpeg
import cloudinary
import cloudinary.uploader

logger = logging.getLogger("video-worker.tasks")

# --- Configuration ---

# Maximum allowed file size for download (500 MB)
MAX_DOWNLOAD_SIZE_BYTES = 500 * 1024 * 1024

# Timeout for downloading the source video (seconds)
DOWNLOAD_TIMEOUT_SECONDS = 300

# Timeout for notifying the Go API callback (seconds)
CALLBACK_TIMEOUT_SECONDS = 10

# HLS segment duration in seconds
HLS_SEGMENT_DURATION = 10

# API URL and Key for the internal callback to Go
API_BASE_URL = os.getenv("API_BASE_URL", "http://api:8080")
VIDEO_WORKER_API_KEY = os.getenv("VIDEO_WORKER_API_KEY", "")

# Initialize Cloudinary from CLOUDINARY_URL env var
if os.getenv("CLOUDINARY_URL"):
    cloudinary.config()
    logger.info("Cloudinary configured from CLOUDINARY_URL")
else:
    logger.warning("CLOUDINARY_URL not set. Uploads will fail.")


def _download_video(source_url: str, dest_path: str) -> None:
    """
    Downloads the source video from Cloudinary to a local temporary file.
    Validates the Content-Length header to prevent downloading excessively large files.

    Args:
        source_url: The public URL of the original MP4 on Cloudinary.
        dest_path: Local file path to save the downloaded video.

    Raises:
        ValueError: If the file exceeds MAX_DOWNLOAD_SIZE_BYTES.
        requests.RequestException: If the download fails.
    """
    logger.info("Downloading source video from %s", source_url)

    response = requests.get(
        source_url,
        stream=True,
        timeout=DOWNLOAD_TIMEOUT_SECONDS
    )
    response.raise_for_status()

    # Validate Content-Length if available
    content_length = response.headers.get("Content-Length")
    if content_length and int(content_length) > MAX_DOWNLOAD_SIZE_BYTES:
        raise ValueError(
            f"Video too large: {int(content_length)} bytes "
            f"(max: {MAX_DOWNLOAD_SIZE_BYTES} bytes)"
        )

    downloaded_bytes = 0
    with open(dest_path, "wb") as f:
        for chunk in response.iter_content(chunk_size=8192):
            downloaded_bytes += len(chunk)
            if downloaded_bytes > MAX_DOWNLOAD_SIZE_BYTES:
                raise ValueError(
                    f"Download exceeded max size during streaming "
                    f"({MAX_DOWNLOAD_SIZE_BYTES} bytes)"
                )
            f.write(chunk)

    file_size_mb = downloaded_bytes / (1024 * 1024)
    logger.info("Download complete: %.2f MB", file_size_mb)


def _transcode_to_hls(input_path: str, output_dir: str) -> str:
    """
    Transcodes an MP4 video into HLS format using FFmpeg.
    Generates a 720p stream with H.264 encoding and AAC audio.

    Args:
        input_path: Path to the source MP4 file.
        output_dir: Directory where HLS segments and playlist will be saved.

    Returns:
        Path to the master playlist file (.m3u8).

    Raises:
        ffmpeg.Error: If FFmpeg fails during transcoding.
    """
    playlist_path = os.path.join(output_dir, "playlist.m3u8")

    logger.info("Starting FFmpeg HLS transcoding...")

    try:
        (
            ffmpeg
            .input(input_path)
            .output(
                playlist_path,
                format="hls",
                hls_time=HLS_SEGMENT_DURATION,
                hls_list_size=0,
                hls_segment_filename=os.path.join(output_dir, "segment_%03d.ts"),
                vcodec="libx264",
                acodec="aac",
                preset="fast",
                crf=23,
                vf="scale=-2:720",
                movflags="+faststart",
            )
            .overwrite_output()
            .run(capture_stdout=True, capture_stderr=True)
        )
    except ffmpeg.Error as e:
        stderr_output = e.stderr.decode("utf-8", errors="replace") if e.stderr else "N/A"
        logger.error("FFmpeg failed: %s", stderr_output)
        raise

    segment_count = len(glob.glob(os.path.join(output_dir, "*.ts")))
    logger.info(
        "Transcoding complete: %d segments generated",
        segment_count
    )

    return playlist_path


def _upload_hls_to_cloudinary(output_dir: str, video_id: str) -> str:
    """
    Uploads all HLS segments (.ts) and the playlist (.m3u8) to Cloudinary.

    Cloudinary stores them as raw files, and we return the URL of the
    master playlist which the video player can use for adaptive streaming.

    Args:
        output_dir: Directory containing the HLS files.
        video_id: Unique identifier for organizing files in Cloudinary.

    Returns:
        The public URL of the uploaded .m3u8 playlist.

    Raises:
        Exception: If any upload to Cloudinary fails.
    """
    logger.info("Uploading HLS files to Cloudinary...")
    folder = f"videos/hls/{video_id}"
    playlist_url = ""

    # Upload all .ts segments first
    ts_files = sorted(glob.glob(os.path.join(output_dir, "*.ts")))
    for ts_file in ts_files:
        filename = os.path.basename(ts_file).replace(".ts", "")
        result = cloudinary.uploader.upload(
            ts_file,
            resource_type="raw",
            folder=folder,
            public_id=filename,
            overwrite=True
        )
        logger.debug("Uploaded segment: %s", result.get("secure_url", ""))

    # Upload the .m3u8 playlist last
    playlist_path = os.path.join(output_dir, "playlist.m3u8")
    if os.path.exists(playlist_path):
        result = cloudinary.uploader.upload(
            playlist_path,
            resource_type="raw",
            folder=folder,
            public_id="playlist",
            overwrite=True
        )
        playlist_url = result.get("secure_url", "")
        logger.info("Playlist uploaded: %s", playlist_url)

    uploaded_count = len(ts_files) + 1
    logger.info("Upload complete: %d files uploaded to Cloudinary", uploaded_count)

    return playlist_url


def _notify_api_backend(video_id: str, hls_url: str, status: str = "ready") -> None:
    """
    Notifies the Go API backend that video processing is complete (or failed).
    Uses an internal API key for authentication.

    Args:
        video_id: The database ID of the processed video.
        hls_url: The public URL of the HLS playlist.
        status: Either "ready" (success) or "failed" (error).
    """
    callback_url = f"{API_BASE_URL}/api/v1/internal/video-ready"

    payload = {
        "video_id": video_id,
        "hls_url": hls_url,
        "status": status,
    }

    headers = {
        "Content-Type": "application/json",
        "X-Internal-API-Key": VIDEO_WORKER_API_KEY,
    }

    try:
        response = requests.post(
            callback_url,
            json=payload,
            headers=headers,
            timeout=CALLBACK_TIMEOUT_SECONDS
        )
        response.raise_for_status()
        logger.info(
            "API notified successfully: video_id=%s, status=%s",
            video_id, status
        )
    except requests.RequestException as e:
        logger.error(
            "Failed to notify API for video %s: %s",
            video_id, str(e)
        )


def process_video_hls(video_id: str, source_url: str) -> dict:
    """
    Main task: Downloads, transcodes to HLS, uploads, and notifies the backend.

    This function is called by the RQ worker when a new video processing
    task is dequeued from Redis. It orchestrates the full pipeline:

    1. Download the original MP4 from Cloudinary.
    2. Transcode to HLS (720p) using FFmpeg.
    3. Upload HLS segments and playlist to Cloudinary.
    4. Notify the Go API backend with the final HLS URL.

    Args:
        video_id: The database ID of the video to process.
        source_url: The Cloudinary URL of the original MP4.

    Returns:
        A dict with the processing result status and HLS URL.
    """
    logger.info(
        "=== Starting HLS processing for video ID: %s ===",
        video_id
    )

    try:
        with tempfile.TemporaryDirectory() as tmpdir:
            input_file = os.path.join(tmpdir, f"{video_id}_input.mp4")
            output_dir = os.path.join(tmpdir, "hls")
            os.makedirs(output_dir, exist_ok=True)

            # Step 1: Download source video
            _download_video(source_url, input_file)

            # Step 2: Transcode to HLS
            _transcode_to_hls(input_file, output_dir)

            # Step 3: Upload HLS files to Cloudinary
            hls_url = _upload_hls_to_cloudinary(output_dir, video_id)

            if not hls_url:
                raise RuntimeError("HLS playlist URL is empty after upload")

            # Step 4: Notify the Go API backend
            _notify_api_backend(video_id, hls_url, status="ready")

            logger.info(
                "=== Video %s processed successfully. HLS URL: %s ===",
                video_id, hls_url
            )

            return {
                "status": "success",
                "video_id": video_id,
                "hls_url": hls_url
            }

    except Exception as e:
        logger.error(
            "=== Video %s processing FAILED: %s ===",
            video_id, str(e)
        )

        # Notify the backend that processing failed
        _notify_api_backend(video_id, "", status="failed")

        raise
