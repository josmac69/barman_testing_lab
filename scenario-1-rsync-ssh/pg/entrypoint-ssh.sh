#!/bin/bash
set -e

# Setup SSH keys directory for postgres user
SSH_DIR="/var/lib/postgresql/.ssh"
mkdir -p "$SSH_DIR"
chmod 750 /var/lib/postgresql

# Copy keys if they exist in the mount point
if [ -d "/ssh-keys" ]; then
    echo "Provisioning SSH keys for postgres user..."
    if [ -f "/ssh-keys/id_rsa_postgres" ]; then
        cp /ssh-keys/id_rsa_postgres "$SSH_DIR/id_rsa"
    fi
    if [ -f "/ssh-keys/id_rsa_postgres.pub" ]; then
        cp /ssh-keys/id_rsa_postgres.pub "$SSH_DIR/id_rsa.pub"
    fi
    if [ -f "/ssh-keys/authorized_keys_postgres" ]; then
        cp /ssh-keys/authorized_keys_postgres "$SSH_DIR/authorized_keys"
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
    chown -R postgres:postgres "$SSH_DIR"
    chmod 700 "$SSH_DIR"
    chmod 600 "$SSH_DIR/id_rsa" || true
    chmod 644 "$SSH_DIR/authorized_keys" || true
    chmod 644 "$SSH_DIR/config"
else
    echo "Warning: /ssh-keys directory not found. SSH backup might fail."
fi

# Generate host keys for sshd if they don't exist
ssh-keygen -A

# Start SSH daemon
echo "Starting SSH daemon..."
/usr/sbin/sshd

# Run the official PostgreSQL entrypoint
echo "Starting PostgreSQL..."
exec /usr/local/bin/docker-entrypoint.sh "$@"
