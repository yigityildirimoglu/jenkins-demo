#!/bin/bash

# Docker daemon'ı başlat
echo "Starting Docker daemon..."
dockerd --iptables=false --bridge=none &
DOCKER_PID=$!

# Docker daemon'ın başlamasını bekle
echo "Waiting for Docker daemon to start..."
while ! docker info > /dev/null 2>&1; do
    sleep 1
done
echo "Docker daemon started successfully!"

# Jenkins'i başlat
echo "Starting Jenkins..."
exec /usr/local/bin/jenkins.sh "$@"
