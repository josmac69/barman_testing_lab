FROM postgres:15

# Install SSH daemon, rsync, sudo, and barman-cli (for barman-wal-restore)
RUN apt-get update && apt-get install -y \
    openssh-server \
    rsync \
    sudo \
    barman-cli \
    && rm -rf /var/lib/apt/lists/*

# Configure SSH daemon
RUN mkdir -p /var/run/sshd && \
    echo 'postgres:postgres' | chpasswd && \
    # Allow postgres user to run passwordless sudo (needed for some recovery scenarios or ssh operations)
    echo "postgres ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Expose SSH and PG ports
EXPOSE 22 5432

# Copy custom entrypoint script to set up SSH keys before starting pg
COPY entrypoint-ssh.sh /usr/local/bin/entrypoint-ssh.sh
RUN chmod +x /usr/local/bin/entrypoint-ssh.sh

ENTRYPOINT ["/usr/local/bin/entrypoint-ssh.sh"]
CMD ["postgres"]
