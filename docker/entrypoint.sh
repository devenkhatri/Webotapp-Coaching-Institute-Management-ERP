#!/bin/sh
set -e

# Wait for database availability if DB_HOST is defined
if [ -n "$DB_HOST" ]; then
    echo "Waiting for database connection at $DB_HOST:${DB_PORT:-3306}..."
    while ! nc -z "$DB_HOST" "${DB_PORT:-3306}"; do
        sleep 1
    done
    echo "Database ($DB_HOST:${DB_PORT:-3306}) is ready!"
fi

# Ensure storage and bootstrap/cache permissions
mkdir -p /var/www/html/storage/framework/cache \
         /var/www/html/storage/framework/sessions \
         /var/www/html/storage/framework/views \
         /var/www/html/storage/logs \
         /var/www/html/bootstrap/cache

chown -R www-data:www-data /var/www/html/storage /var/www/html/bootstrap/cache
chmod -R 775 /var/www/html/storage /var/www/html/bootstrap/cache

# Generate application key if not set
if [ -f /var/www/html/.env ] && ! grep -q "^APP_KEY=base64:" /var/www/html/.env; then
    echo "Generating application key..."
    php artisan key:generate --force
fi

# Create SQLite database file if driver is sqlite and file doesn't exist
if [ "$DB_CONNECTION" = "sqlite" ] && [ ! -f "${DB_DATABASE:-/var/www/html/database/database.sqlite}" ]; then
    mkdir -p "$(dirname "${DB_DATABASE:-/var/www/html/database/database.sqlite}")"
    touch "${DB_DATABASE:-/var/www/html/database/database.sqlite}"
    chown -R www-data:www-data "$(dirname "${DB_DATABASE:-/var/www/html/database/database.sqlite}")"
fi

echo "Laravel container initialization completed."

# Execute CMD passed to container
exec "$@"
