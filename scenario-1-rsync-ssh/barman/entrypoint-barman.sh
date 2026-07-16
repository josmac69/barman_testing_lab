#!/bin/bash
set -e

# Setup SSH keys directory for barman user
SSH_DIR="/var/lib/barman/.ssh"
mkdir -p "$SSH_DIR"

# Copy keys if they exist in the mount point
if [ -d "/ssh-keys" ]; then
    echo "Provisioning SSH keys for barman user..."
    if [ -f "/ssh-keys/id_rsa_barman" ]; then
        cp /ssh-keys/id_rsa_barman "$SSH_DIR/id_rsa"
    fi
    if [ -f "/ssh-keys/id_rsa_barman.pub" ]; then
        cp /ssh-keys/id_rsa_barman.pub "$SSH_DIR/id_rsa.pub"
    fi
    if [ -f "/ssh-keys/authorized_keys_barman" ]; then
        cp /ssh-keys/authorized_keys_barman "$SSH_DIR/authorized_keys"
    fi

    # Create config to allow passwordless connections without interactive prompt
    cat <<EOF > "$SSH_DIR/config"
Host *
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
    IdentityFile $SSH_DIR/id_rsa
    LogLevel QUIET
EOF

    # Fix permissions
    chown -R barman:barman "$SSH_DIR"
    chmod 700 "$SSH_DIR"
    chmod 600 "$SSH_DIR/id_rsa" || true
    chmod 644 "$SSH_DIR/authorized_keys" || true
    chmod 644 "$SSH_DIR/config"
else
    echo "Warning: /ssh-keys directory not found. SSH backup might fail."
fi

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
mkdir -p /var/lib/barman/pg/incoming
chown -R barman:barman /var/lib/barman

# Generate host keys for sshd if they don't exist
ssh-keygen -A

# Start SSH daemon
echo "Starting SSH daemon..."
/usr/sbin/sshd

# Start Barman Prometheus Exporter if present
if [ -f "/usr/local/bin/barman_prometheus_exporter.py" ]; then
    echo "Starting Barman Prometheus Exporter..."
    sudo -u barman python3 /usr/local/bin/barman_prometheus_exporter.py &
fi

# Run the CMD
echo "Starting Barman Container Command..."
exec "$@"
