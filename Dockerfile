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

# Patch legacy import in gpt_researcher 0.14.3
# Replace: from langchain.docstore.document import Document
# With:    from langchain_core.documents import Document
RUN python - <<'PY'
import inspect, pathlib, gpt_researcher
p = pathlib.Path(inspect.getfile(gpt_researcher)).parent / 'prompts.py'
s = p.read_text()
old = 'from langchain.docstore.document import Document'
new = 'from langchain_core.documents import Document'
if old in s:
    s = s.replace(old, new)
    p.write_text(s)
    print('Patched', p)
else:
    print('No legacy import found in', p)
PY

# Fail fast: verify modern import works
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

HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD curl -fsS http://localhost:8000/health || exit 1

CMD ["python", "server.py"]