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

# Bağımlılıkları system-wide kur (--system flag ile)
RUN uv sync --frozen --no-cache --system

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

# Builder stage'den Python paketlerini kopyala
COPY --from=builder /usr/local/lib/python3.11/site-packages /usr/local/lib/python3.11/site-packages
COPY --from=builder /usr/local/bin /usr/local/bin

# Uygulama kodunu kopyala
COPY --chown=appuser:appuser ./app /app

# Python optimizasyonları
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONPATH=/app

# Non-root user'a geç
USER appuser

# Health check ekle
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8000/health || exit 1

# Port expose et
EXPOSE 8000

# Application'ı başlat
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]