# Use the official Python slim image as a base
FROM python:3.11-slim

# Set the working directory in the container
WORKDIR /app

# 1. Install necessary system packages including curl
#    Clean up apt cache afterwards to keep the image slim
RUN apt-get update && \
    apt-get install -y --no-install-recommends curl && \
    rm -rf /var/lib/apt/lists/*

# 2. Install uv using the downloaded curl
RUN curl -LsSf https://astral.sh/uv/install.sh | sh

# 3. Add uv's bin directory to the PATH environment variable
#    This ensures subsequent RUN, CMD, ENTRYPOINT commands can find 'uv'
ENV PATH="/root/.cargo/bin:${PATH}"

# 4. Copy the requirements file into the container
COPY requirements.txt requirements.txt

# 5. Install Python dependencies using uv
#    Using --system installs packages globally in the image (common for containers)
#    Using --no-cache helps reduce final image size
RUN uv pip install --no-cache --system -r requirements.txt

# 6. Copy the rest of the application code into the container
COPY ./app /app

# 7. Specify the command to run when the container starts
#    Runs uvicorn, serving the FastAPI app defined in app/main.py
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]