FROM python:3.11-slim-bookworm

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_DEFAULT_TIMEOUT=120

WORKDIR /app

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
      libopenblas0 \
      libgomp1 \
      curl \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .

# Installer PyTorch CPU-only séparément pour éviter les énormes dépendances CUDA.
# Version alignée avec l'installation Jenkins qui passe déjà en local.
RUN python -m pip install --upgrade pip \
    && pip install --no-cache-dir --index-url https://download.pytorch.org/whl/cpu torch==2.2.2 \
    && pip install --no-cache-dir -r requirements.txt

COPY . .

EXPOSE 8000

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
