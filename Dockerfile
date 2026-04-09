FROM php:8.2-apache

# Fix Apache MPM issue early - disable all MPM modules, then enable only mpm_prefork.
# This must happen before any other Apache configuration to avoid "More than one MPM loaded".
RUN a2dismod mpm_event mpm_worker mpm_async 2>/dev/null || true && \
    a2enmod mpm_prefork

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
    curl \
  && docker-php-ext-configure gd --with-freetype --with-jpeg \
  && docker-php-ext-install -j$(nproc) gd pdo pdo_mysql zip bcmath intl \
  && pecl install redis \
  && docker-php-ext-enable redis \
  && a2enmod rewrite \
  && rm -rf /var/lib/apt/lists/*

# Install Composer.
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

WORKDIR /var/www/html

# Copy dependency definitions into the Laravel app directory and install PHP dependencies.
COPY core/composer.json core/composer.lock ./core/
WORKDIR /var/www/html/core
RUN composer install --no-dev --prefer-dist --optimize-autoloader --no-interaction --no-scripts

WORKDIR /var/www/html

# Copy application files.
COPY . .

# Generate optimized autoloader and set storage permissions in the Laravel app.
WORKDIR /var/www/html/core
RUN composer dump-autoload --optimize \
  && chown -R www-data:www-data /var/www/html/core/storage /var/www/html/core/bootstrap/cache \
  && chmod -R 775 /var/www/html/core/storage /var/www/html/core/bootstrap/cache

# Set Apache document root to the Laravel public directory.
ENV APACHE_DOCUMENT_ROOT /var/www/html/public
RUN sed -ri 's!/var/www/html!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/sites-available/000-default.conf && \
    sed -i 's/<VirtualHost \*:80>/<VirtualHost 0.0.0.0:80>/g' /etc/apache2/sites-available/000-default.conf

# Configure Apache to listen on all interfaces (0.0.0.0) on port 80
RUN echo 'Listen 0.0.0.0:80' > /etc/apache2/ports.conf

# Configure Apache for better performance and security
RUN echo 'ServerTokens Prod' >> /etc/apache2/conf-enabled/security.conf && \
    echo 'ServerSignature Off' >> /etc/apache2/conf-enabled/security.conf && \
    echo 'ServerName 0.0.0.0' >> /etc/apache2/apache2.conf

# Copy startup script
COPY start.sh /usr/local/bin/start.sh
RUN chmod +x /usr/local/bin/start.sh

# Set environment variables for Railway
ENV APP_ENV=production
ENV APP_DEBUG=false
ENV LOG_CHANNEL=stderr

EXPOSE 80
CMD ["/usr/local/bin/start.sh"]
