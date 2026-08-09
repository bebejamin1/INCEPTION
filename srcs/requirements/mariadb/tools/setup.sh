#!/bin/bash
set -e

DATADIR=/var/lib/mysql

DB_PASSWORD=$(cat "$MYSQL_PASSWORD_FILE")
DB_ROOT_PASSWORD=$(cat "$MYSQL_ROOT_PASSWORD_FILE")

if [ ! -d "$DATADIR/mysql" ]; then
    echo "[setup] Initializing MariaDB data directory..."
    mariadb-install-db \
        --user=mysql \
        --datadir="$DATADIR" \
        --auth-root-authentication-method=normal \
        > /dev/null

    echo "[setup] Starting temporary server to create database and users..."
    mysqld --user=mysql --datadir="$DATADIR" --skip-networking &
    tmp_pid="$!"

    for i in $(seq 1 30); do
        mysqladmin --socket=/run/mysqld/mysqld.sock ping >/dev/null 2>&1 && break
        sleep 1
    done

    mysql --socket=/run/mysqld/mysqld.sock -u root <<-EOSQL
        CREATE DATABASE IF NOT EXISTS \`${MYSQL_DATABASE}\`;
        CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%' IDENTIFIED BY '${DB_PASSWORD}';
        GRANT ALL PRIVILEGES ON \`${MYSQL_DATABASE}\`.* TO '${MYSQL_USER}'@'%';
        ALTER USER 'root'@'localhost' IDENTIFIED BY '${DB_ROOT_PASSWORD}';
        FLUSH PRIVILEGES;
EOSQL

    mysqladmin --socket=/run/mysqld/mysqld.sock -u root -p"${DB_ROOT_PASSWORD}" shutdown
    wait "$tmp_pid" 2>/dev/null || true
    echo "[setup] Database initialized."
fi

echo "[setup] Starting MariaDB..."
exec mysqld --user=mysql --datadir="$DATADIR"
