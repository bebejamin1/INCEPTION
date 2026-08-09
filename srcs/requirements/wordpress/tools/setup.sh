#!/bin/bash
set -e

WP_PATH=/var/www/html

DB_PASSWORD=$(cat "$MYSQL_PASSWORD_FILE")
WP_ADMIN_PASSWORD=$(grep '^WP_ADMIN_PASSWORD=' "$CREDENTIALS_FILE" | cut -d '=' -f2-)
WP_USER_PASSWORD=$(grep '^WP_USER_PASSWORD=' "$CREDENTIALS_FILE" | cut -d '=' -f2-)

echo "[setup] Waiting for MariaDB at ${WORDPRESS_DB_HOST}:3306..."
until (exec 3<>"/dev/tcp/${WORDPRESS_DB_HOST}/3306") 2>/dev/null; do
    sleep 2
done
exec 3<&- 3>&- 2>/dev/null || true
echo "[setup] MariaDB is reachable."

cd "$WP_PATH"

if [ ! -f wp-config.php ]; then
    echo "[setup] Downloading WordPress core..."
    wp core download --allow-root

    echo "[setup] Creating wp-config.php..."
    wp config create \
        --dbname="$MYSQL_DATABASE" \
        --dbuser="$MYSQL_USER" \
        --dbpass="$DB_PASSWORD" \
        --dbhost="$WORDPRESS_DB_HOST" \
        --allow-root

    echo "[setup] Installing WordPress..."
    wp core install \
        --url="https://${DOMAIN_NAME}" \
        --title="$WP_TITLE" \
        --admin_user="$WP_ADMIN_USER" \
        --admin_password="$WP_ADMIN_PASSWORD" \
        --admin_email="$WP_ADMIN_EMAIL" \
        --skip-email \
        --allow-root

    echo "[setup] Creating second (non-admin) user..."
    wp user create "$WP_USER" "$WP_USER_EMAIL" \
        --role=author \
        --user_pass="$WP_USER_PASSWORD" \
        --allow-root

    wp rewrite structure '/%postname%/' --allow-root
fi

chown -R www-data:www-data "$WP_PATH"

echo "[setup] Starting php-fpm..."
exec php-fpm8.2 -F
