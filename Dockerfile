# Use the official Python slim image as a base
FROM python:3.11-slim

# Set the working directory in the container
WORKDIR /app

# 1. Install necessary system packages including curl
RUN apt-get update && \
    apt-get install -y --no-install-recommends curl && \
    rm -rf /var/lib/apt/lists/*

# 2. Install uv using the downloaded curl
RUN curl -LsSf https://astral.sh/uv/install.sh | sh

# *** DÜZELTME: Doğru yolu PATH'e ekle ***
ENV PATH="/root/.local/bin:${PATH}"

# 4. Copy the requirements file into the container
COPY requirements.txt requirements.txt

# 5. Install Python dependencies using uv (Artık uv PATH'de olmalı)
RUN uv pip install --no-cache --system -r requirements.txt

# 6. Copy the rest of the application code into the container
COPY ./app /app

# 7. Specify the command to run when the container starts
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]