FROM python:3.11-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

WORKDIR /app

# System deps for healthcheck + TLS
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl ca-certificates git \
    && rm -rf /var/lib/apt/lists/*

# Install Python deps
COPY requirements.txt .
# Preinstall numpy so faiss picks the right wheel
RUN pip install --upgrade pip && \
    pip install --no-cache-dir numpy==2.3.1 && \
    pip install --no-cache-dir faiss-cpu==1.9.0 && \
    pip install --no-cache-dir -r requirements.txt

# (the 0.14.3-era legacy-import patch is gone: verified absent from
# gpt_researcher >= 0.14.7 prompts.py)

# Fail fast: print the resolved gpt-researcher version and verify the
# modern import works
RUN python - <<'PY'
import gpt_researcher, langchain
print('gptr', getattr(gpt_researcher,'__version__',None), 'lc', langchain.__version__)
from langchain_core.documents import Document
print('deps ok')
PY

# App code
COPY . .

ENV MCP_TRANSPORT=sse \
    DOCKER_CONTAINER=true \
    PYTHONUNBUFFERED=1

EXPOSE 8000

CMD ["python", "server.py"]