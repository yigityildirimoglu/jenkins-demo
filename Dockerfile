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

# 4. Bağımlılık dosyasını (requirements.txt) konteynere kopyalıyoruz.
COPY requirements.txt requirements.txt

# 5. Proje bağımlılıklarını uv kullanarak kuruyoruz.
RUN uv pip install --no-cache --system -r requirements.txt

# 6. Uygulama kodumuzu (yerel ./app dizinini) konteynerdeki /app dizinine kopyalıyoruz.
COPY ./app /app

# 7. Python'a /app dizinini import edebileceği yollara eklemesini söylüyoruz (Ekstra güvence).
ENV PYTHONPATH=/app

# 8. Konteyner başladığında çalıştırılacak varsayılan komut.
#    DÜZELTME: 'app.main:app' yerine 'main:app' kullanılıyor.
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]