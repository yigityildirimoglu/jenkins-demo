# Temel imaj olarak resmi Python slim sürümünü kullanıyoruz.
FROM python:3.11-slim

# Konteyner içindeki çalışma dizinini /app olarak ayarlıyoruz.
WORKDIR /app

# 1. Gerekli sistem paketlerini (curl dahil) kuruyoruz.
RUN apt-get update && \
    apt-get install -y --no-install-recommends curl && \
    rm -rf /var/lib/apt/lists/*

# 2. uv paket yöneticisini curl kullanarak indirip kuruyoruz.
RUN curl -LsSf https://astral.sh/uv/install.sh | sh

# 3. uv'nin kurulduğu dizini (/root/.local/bin) PATH ortam değişkenine ekliyoruz.
ENV PATH="/root/.local/bin:${PATH}"

# 4. Proje tanım ve kilit dosyalarını kopyalıyoruz.
COPY pyproject.toml uv.lock ./

# 5. Proje bağımlılıklarını uv sync kullanarak KİLİT DOSYASINDAN kuruyoruz.
#    DÜZELTME: --system kaldırıldı.
RUN uv sync --no-cache

# 6. Uygulama kodumuzu (yerel ./app dizinini) konteynerdeki /app dizinine kopyalıyoruz.
COPY ./app /app

# 7. Python'a /app dizinini import edebileceği yollara eklemesini söylüyoruz.
ENV PYTHONPATH=/app

# 8. Konteyner başladığında çalıştırılacak varsayılan komut.
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]