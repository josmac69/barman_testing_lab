FROM debian:bookworm-slim

# Install dependencies, barman, and PostgreSQL client 15
RUN apt-get update && apt-get install -y \
    curl \
    gnupg \
    procps \
    openssh-server \
    openssh-client \
    rsync \
    sudo \
    postgresql-client-15 \
    barman \
    && rm -rf /var/lib/apt/lists/*

# Configure SSH daemon
RUN mkdir /var/run/sshd && \
    echo 'barman:barman' | chpasswd && \
    # Allow barman user to run passwordless sudo (needed for recovery actions)
    echo "barman ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Create log file and fix permissions for barman user
RUN touch /var/log/barman.log && chown barman:barman /var/log/barman.log

# Expose SSH
EXPOSE 22

# Copy custom entrypoint script to set up SSH keys before starting
COPY entrypoint-barman.sh /usr/local/bin/entrypoint-barman.sh
RUN chmod +x /usr/local/bin/entrypoint-barman.sh

ENTRYPOINT ["/usr/local/bin/entrypoint-barman.sh"]
CMD ["tail", "-f", "/dev/null"]
