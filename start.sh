#!/bin/bash

# Don't exit on error - we want Apache to start even if migrations fail
set +e

echo "🚀 Starting Laravel application setup..."

# Change to the core directory where Laravel is installed
cd /var/www/html/core

# Run database migrations if database is configured
if [ -n "$DB_HOST" ] && [ -n "$DB_DATABASE" ]; then
    echo "📦 Running database migrations..."
    php artisan migrate --force --no-interaction 2>&1 || echo "⚠️  Migration warning: Some migrations may have failed"
    echo "✅ Migration step completed"
else
    echo "⚠️  Database not configured, skipping migrations"
fi

# Clear and cache configurations
echo "🔧 Optimizing Laravel..."
php artisan config:cache 2>&1 || echo "⚠️  Config cache warning"
php artisan route:cache 2>&1 || echo "⚠️  Route cache warning"
php artisan view:cache 2>&1 || echo "⚠️  View cache warning"
echo "✅ Laravel optimization completed"

# Ensure proper permissions
echo "🔒 Setting permissions..."
chown -R www-data:www-data /var/www/html/core/storage /var/www/html/core/bootstrap/cache 2>&1 || true
chmod -R 775 /var/www/html/core/storage /var/www/html/core/bootstrap/cache 2>&1 || true
echo "✅ Permissions set"

# Start Apache
echo "🌐 Starting Apache web server..."
exec apache2-foreground
