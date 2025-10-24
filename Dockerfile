# ============================================
# Stage 1: Builder - Dependencies kurulumu
# ============================================
FROM python:3.11-slim AS builder

WORKDIR /app

# Sistem bağımlılıklarını kur
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        curl \
        build-essential && \
    rm -rf /var/lib/apt/lists/*

# UV paket yöneticisini kur
RUN curl -LsSf https://astral.sh/uv/install.sh | sh

# UV'yi PATH'e ekle
ENV PATH="/root/.local/bin:${PATH}"

# Dependency dosyalarını kopyala (code'dan önce - cache optimization)
COPY pyproject.toml uv.lock ./

# DÜZELTME: UV 0.9+ versiyonunda --system yok, direkt sync yapıyoruz
# Virtual environment oluşturulacak ama Python paketleri /app/.venv/ içine gidecek
RUN uv sync --frozen --no-cache

# ============================================
# Stage 2: Runtime - Minimal production image
# ============================================
FROM python:3.11-slim AS runtime

WORKDIR /app

# Sadece runtime için gerekli paketler
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        curl && \
    rm -rf /var/lib/apt/lists/*

# Non-root user oluştur (security best practice)
RUN useradd -m -u 1000 appuser && \
    chown -R appuser:appuser /app

# Builder stage'den virtual environment'i kopyala
COPY --from=builder --chown=appuser:appuser /app/.venv /app/.venv

# Uygulama kodunu kopyala
COPY --chown=appuser:appuser ./app /app

# Python optimizasyonları ve virtual env PATH'e ekleme
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONPATH=/app \
    PATH="/app/.venv/bin:${PATH}"

# Non-root user'a geç
USER appuser

# Health check ekle
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8000/health || exit 1

# Port expose et
EXPOSE 8000

# Application'ı başlat (artık uvicorn PATH'te)
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8001"]