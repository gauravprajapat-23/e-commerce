#!/bin/bash

# Exit on error
set -e

echo "🚀 Starting Laravel application setup..."

# Change to the core directory where Laravel is installed
cd /var/www/html/core

# Run database migrations if database is configured
if [ -n "$DB_HOST" ] && [ -n "$DB_DATABASE" ]; then
    echo "📦 Running database migrations..."
    php artisan migrate --force --no-interaction
    echo "✅ Migrations completed"
else
    echo "⚠️  Database not configured, skipping migrations"
fi

# Clear and cache configurations
echo "🔧 Optimizing Laravel..."
php artisan config:cache
php artisan route:cache
php artisan view:cache
echo "✅ Laravel optimized"

# Start Apache
echo "🌐 Starting Apache web server..."
exec apache2-foreground
