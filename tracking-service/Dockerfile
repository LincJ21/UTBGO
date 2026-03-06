# Stage 1: Build dependencies
FROM python:3.11-slim as builder

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc libc-dev libpq-dev \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --user --no-cache-dir -r requirements.txt gunicorn

# Stage 2: Final lightweight image
FROM python:3.11-slim

WORKDIR /app

# Install only necessary runtime libraries
RUN apt-get update && apt-get install -y --no-install-recommends \
    libpq5 \
    && rm -rf /var/lib/apt/lists/*

# Create a non-privileged user
RUN groupadd -r appgroup && useradd -r -g appgroup appuser
USER appuser

# Copy only the installed packages from builder
COPY --from=builder /root/.local /home/appuser/.local
COPY --chown=appuser:appgroup . .

# Update PATH to include local pip bin
ENV PATH=/home/appuser/.local/bin:$PATH

EXPOSE 8091

# Use Gunicorn as process manager
CMD ["gunicorn", "app.main:app", "-w", "4", "-k", "uvicorn.workers.UvicornWorker", "--bind", "0.0.0.0:8091"]
