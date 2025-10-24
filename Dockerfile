FROM python:3.11-slim

WORKDIR /app

# Önce uv'yi kuralım
RUN curl -LsSf https://astral.sh/uv/install.sh | sh
# uv'yi PATH'e ekleyelim ki sonraki RUN komutları bulabilsin
ENV PATH="/root/.cargo/bin:${PATH}"

COPY requirements.txt requirements.txt
# uv ile bağımlılıklar kuruluyor
RUN uv pip install --no-cache --system -r requirements.txt
# --system: Sanal ortam oluşturmadan doğrudan sisteme kurar (Docker imajları için yaygın)
# --no-cache: Docker katmanlarını küçük tutar

COPY ./app /app

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]