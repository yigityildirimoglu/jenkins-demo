#!/bin/bash

# Docker daemon'ı root olarak başlat (eğer çalışmıyorsa)
echo "Checking Docker daemon status..."
if ! docker info > /dev/null 2>&1; then
    # Docker daemon çalışmıyorsa, PID dosyasını temizle
    if [ -f /var/run/docker.pid ]; then
        echo "Removing stale Docker PID file..."
        rm -f /var/run/docker.pid
    fi

    echo "Starting Docker daemon as root..."
    dockerd --bridge=none --data-root /var/lib/docker --iptables=false --storage-driver=vfs &
    DOCKER_PID=$!

    # Docker daemon'ın başlamasını bekle
    echo "Waiting for Docker daemon to start..."
    sleep 10

    # Docker'ın çalışıp çalışmadığını kontrol et
    echo "Checking if Docker daemon is responsive..."
    if ! docker info > /dev/null 2>&1; then
        echo "Docker daemon failed to start!"
        exit 1
    fi

    echo "Docker daemon started successfully!"
else
    echo "Docker daemon is already running!"
fi

# Docker socket'in sahibini root olarak değiştir (artık root kullanıcısıyız)
echo "Setting Docker socket permissions..."
chown root:root /var/run/docker.sock

# Jenkins'i root olarak başlat (Docker yetkileri ile)
echo "Starting Jenkins as root..."
echo "Jenkins should be able to run Docker commands now..."
exec /usr/local/bin/jenkins.sh "$@"
