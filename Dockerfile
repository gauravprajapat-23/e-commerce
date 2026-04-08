FROM php:8.2-apache

# Install system dependencies required for Laravel and common PHP extensions.
RUN apt-get update && apt-get install -y \
    git \
    unzip \
    libzip-dev \
    libpng-dev \
    libjpeg62-turbo-dev \
    libfreetype6-dev \
    libonig-dev \
    libxml2-dev \
    libicu-dev \
    default-mysql-client \
  && docker-php-ext-configure gd --with-freetype --with-jpeg \
  && docker-php-ext-install -j$(nproc) gd pdo pdo_mysql zip bcmath intl \
  && a2enmod rewrite \
  && rm -rf /var/lib/apt/lists/*

# Install Composer.
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

WORKDIR /var/www/html

# Copy dependency definitions and install PHP dependencies first for better build caching.
COPY core/composer.json core/composer.lock ./
RUN composer install --no-dev --prefer-dist --optimize-autoloader --no-interaction --no-scripts

# Copy application files.
COPY . .

# Generate optimized autoloader and set storage permissions.
RUN composer dump-autoload --optimize \
  && chown -R www-data:www-data /var/www/html/core/storage /var/www/html/core/bootstrap/cache \
  && chmod -R 775 /var/www/html/core/storage /var/www/html/core/bootstrap/cache

# Set Apache document root to the Laravel public directory.
ENV APACHE_DOCUMENT_ROOT /var/www/html/public
RUN sed -ri 's!/var/www/html!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/sites-available/000-default.conf

EXPOSE 80
CMD ["apache2-foreground"]
