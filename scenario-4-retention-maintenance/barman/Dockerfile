FROM debian:bookworm-slim

# Install dependencies, barman, and PostgreSQL client 15
RUN apt-get update && apt-get install -y \
    curl \
    gnupg \
    procps \
    sudo \
    postgresql-client-15 \
    barman \
    && rm -rf /var/lib/apt/lists/*

# Allow barman user to run passwordless sudo
RUN echo "barman ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Create log file and fix permissions
RUN touch /var/log/barman.log && chown barman:barman /var/log/barman.log

# Copy custom entrypoint script
COPY entrypoint-barman.sh /usr/local/bin/entrypoint-barman.sh
RUN chmod +x /usr/local/bin/entrypoint-barman.sh

ENTRYPOINT ["/usr/local/bin/entrypoint-barman.sh"]
CMD ["tail", "-f", "/dev/null"]
