#!/bin/bash
set -e

SSL_DIR=/etc/nginx/ssl
mkdir -p "$SSL_DIR"

if [ ! -f "$SSL_DIR/inception.crt" ]; then
    echo "[setup] Generating self-signed TLS certificate for ${DOMAIN_NAME}..."
    openssl req -x509 -nodes -days 365 \
        -newkey rsa:2048 \
        -keyout "$SSL_DIR/inception.key" \
        -out "$SSL_DIR/inception.crt" \
        -subj "/C=FR/ST=IDF/L=Paris/O=42/OU=Inception/CN=${DOMAIN_NAME}"
fi

envsubst '${DOMAIN_NAME}' < /etc/nginx/nginx.conf.template > /etc/nginx/nginx.conf

echo "[setup] Starting NGINX..."
exec nginx -g "daemon off;"
