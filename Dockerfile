FROM debian:stable-slim
LABEL org.opencontainers.image.authors="3454862+jeansf@users.noreply.github.com"
LABEL maintainer="Jean Soares Fernandes <3454862+jeansf@users.noreply.github.com>"

# Set noninteractive mode for apt-get
ENV DEBIAN_FRONTEND=noninteractive

# Start editing
# Install package here for cache
RUN apt-get update && apt-get -y install \
    supervisor postfix sasl2-bin opendkim opendkim-tools cron python3 python3-venv libaugeas0 && \
    rm -rf /var/lib/apt/lists/*
RUN python3 -m venv /opt/certbot/ && \
    /opt/certbot/bin/pip install --no-cache-dir --upgrade pip && \
    /opt/certbot/bin/pip install --no-cache-dir certbot certbot-dns-cloudflare && \
    ln -s /opt/certbot/bin/certbot /usr/bin/certbot

# Add files
ADD assets/install.sh /opt/install.sh

EXPOSE 25 587

# Run
CMD /opt/install.sh;/usr/bin/supervisord -c /etc/supervisor/supervisord.conf
