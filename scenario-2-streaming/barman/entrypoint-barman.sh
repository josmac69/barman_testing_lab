#!/bin/bash
set -e

# Copy configs from /tmp/configs if present
mkdir -p /etc/barman.d
if [ -d "/tmp/configs" ]; then
    echo "Copying Barman configs..."
    if [ -f "/tmp/configs/barman.conf" ]; then
        cp /tmp/configs/barman.conf /etc/barman.conf
    fi
    if [ -f "/tmp/configs/pg.conf" ]; then
        cp /tmp/configs/pg.conf /etc/barman.d/pg.conf
    fi
    chown -R barman:barman /etc/barman.conf /etc/barman.d
fi

# Make sure all of barman's directory is owned by barman
chown -R barman:barman /var/lib/barman

# Start Barman Prometheus Exporter if present
if [ -f "/usr/local/bin/barman_prometheus_exporter.py" ]; then
    echo "Starting Barman Prometheus Exporter..."
    sudo -u barman python3 /usr/local/bin/barman_prometheus_exporter.py &
fi

echo "Starting Barman Container Command..."
exec "$@"
