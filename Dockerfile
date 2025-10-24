# Temel imaj olarak resmi Python slim sürümünü kullanıyoruz.
FROM python:3.11-slim

# Konteyner içindeki çalışma dizinini /app olarak ayarlıyoruz.
# Sonraki COPY ve CMD komutları bu dizin göreceli çalışır.
WORKDIR /app

# 1. Gerekli sistem paketlerini (curl dahil) kuruyoruz.
#    apt önbelleğini temizleyerek imaj boyutunu küçültüyoruz.
RUN apt-get update && \
    apt-get install -y --no-install-recommends curl && \
    rm -rf /var/lib/apt/lists/*

# 2. uv paket yöneticisini curl kullanarak indirip kuruyoruz.
RUN curl -LsSf https://astral.sh/uv/install.sh | sh

# 3. uv'nin kurulduğu dizini (/root/.local/bin) PATH ortam değişkenine ekliyoruz.
#    Bu, sonraki RUN ve CMD komutlarının 'uv' komutunu bulmasını sağlar.
ENV PATH="/root/.local/bin:${PATH}"

# 4. Bağımlılık dosyasını (requirements.txt) konteynere kopyalıyoruz.
COPY requirements.txt requirements.txt

# 5. Proje bağımlılıklarını uv kullanarak kuruyoruz.
#    --system: Paketleri sanal ortam olmadan doğrudan sisteme kurar.
#    --no-cache: İmaj boyutunu küçültmek için indirme önbelleğini kullanmaz/saklamaz.
RUN uv pip install --no-cache --system -r requirements.txt

# 6. Uygulama kodumuzu (yerel ./app dizinini) konteynerdeki /app dizinine kopyalıyoruz.
COPY ./app /app

# 7. Python'a /app dizinini import edebileceği yollara eklemesini söylüyoruz.
#    Bu, "ModuleNotFoundError: No module named 'app'" hatasını çözer.
ENV PYTHONPATH=/app

# 8. Konteyner başladığında çalıştırılacak varsayılan komut.
#    uvicorn'u başlatarak app/main.py içindeki FastAPI uygulamasını (app) sunar.
#    --host 0.0.0.0: Konteyner dışından erişime izin verir.
#    --port 8000: Konteyner içinde 8000 portunu kullanır.
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]