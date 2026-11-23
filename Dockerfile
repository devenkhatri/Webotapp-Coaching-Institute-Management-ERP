# syntax=docker/dockerfile:1

# -------------------------------------------------------------
# Stage 1: Build Frontend Assets (Vite, Tailwind, Alpine, Chart.js)
# -------------------------------------------------------------
FROM node:20-alpine AS frontend-builder
WORKDIR /app

COPY package.json package-lock.json ./
RUN npm ci

COPY vite.config.js tailwind.config.js postcss.config.js ./
COPY resources resources
RUN npm run build

# -------------------------------------------------------------
# Stage 2: Install Composer Dependencies (PHP Vendor)
# -------------------------------------------------------------
FROM composer:2 AS composer-builder
WORKDIR /app

COPY composer.json composer.lock ./
RUN composer install \
    --no-dev \
    --no-interaction \
    --prefer-dist \
    --no-autoloader \
    --no-scripts

# Copy code needed for PSR-4 autoload classmap generation
COPY app app/
COPY database database/

RUN composer dump-autoload --optimize --no-dev

# -------------------------------------------------------------
# Stage 3: Final Production & Development PHP-FPM Runtime
# -------------------------------------------------------------
FROM php:8.3-fpm-alpine AS runtime

# Install system dependencies
RUN apk add --no-cache \
    netcat-openbsd \
    curl \
    git \
    unzip \
    bash \
    icu-data-full

# Install PHP extensions using docker-php-extension-installer
COPY --from=mlocati/php-extension-installer /usr/bin/install-php-extensions /usr/local/bin/
RUN install-php-extensions \
    pdo_mysql \
    pdo_sqlite \
    bcmath \
    ctype \
    curl \
    dom \
    fileinfo \
    filter \
    gd \
    intl \
    mbstring \
    opcache \
    openssl \
    pcntl \
    phar \
    redis \
    session \
    tokenizer \
    xml \
    zip

# Copy Composer binary from official image
COPY --from=composer:2 /usr/bin/composer /usr/local/bin/composer

# Copy PHP and Opcache configurations
COPY docker/php/php.ini /usr/local/etc/php/conf.d/custom.ini
COPY docker/php/opcache.ini /usr/local/etc/php/conf.d/opcache.ini

# Set working directory
WORKDIR /var/www/html

# Copy application source code
COPY . /var/www/html

# Copy built vendor packages and frontend assets
COPY --from=composer-builder /app/vendor /var/www/html/vendor
COPY --from=frontend-builder /app/public/build /var/www/html/public/build

# Copy entrypoint script
COPY docker/entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# Configure directory permissions for Laravel runtime
RUN chown -R www-data:www-data /var/www/html/storage /var/www/html/bootstrap/cache \
    && chmod -R 775 /var/www/html/storage /var/www/html/bootstrap/cache

EXPOSE 9000

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["php-fpm"]
