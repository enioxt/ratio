FROM python:3.11-slim

WORKDIR /app

# System deps for sentence-transformers + PyMuPDF + lancedb
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    libglib2.0-0 \
    libsm6 \
    libxext6 \
    libxrender-dev \
    git \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements first for layer caching
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy source
COPY backend/ ./backend/
COPY rag/ ./rag/
COPY frontend/ ./frontend/
COPY version.json .

# LanceDB store and data are expected to be volume-mounted at runtime:
#   /app/lancedb_store  — vector index (~8.5GB)
#   /app/data           — SQLite sources (~14.9GB, optional for query-only mode)
#   /app/logs           — log output

ENV PYTHONPATH=/app
ENV PYTHONUNBUFFERED=1
# Escritório Caddy-internal URL for Guard Brasil (already running on VPS)
ENV GUARD_BRASIL_URL=http://guard-brasil-api:3099
# Disable PII guard by default; enable per-deployment via env override
ENV RATIO_PII_GUARD_ENABLED=0

EXPOSE 8000

# Serve FastAPI backend (frontend static files are served via Caddy or nginx sidecar)
CMD ["python", "-m", "uvicorn", "backend.main:app", "--host", "0.0.0.0", "--port", "8000"]
