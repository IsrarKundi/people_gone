# PeopleGone Phase 0 GPU Worker
# CUDA 12.1 + PyTorch 2.4.0 runtime for RunPod Serverless / local GPU
FROM pytorch/pytorch:2.4.0-cuda12.1-cudnn9-runtime

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1 \
    HF_HUB_ENABLE_HF_TRANSFER=0

WORKDIR /app

# Install system dependencies (libGL for headless opencv, git for models if needed)
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    curl \
    libgl1 \
    libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

# Install pinned Python dependencies
COPY requirements.txt /app/requirements.txt
RUN pip install --no-cache-dir -r requirements.txt

# Copy worker application code
COPY worker/ /app/worker/
COPY handler.py /app/handler.py
COPY cli.py /app/cli.py
COPY clipdrop_arm.py /app/clipdrop_arm.py

# Health check / smoke test entry point
CMD ["python", "-u", "handler.py"]
