#!/bin/bash

# Don't exit on error - we want Apache to start even if migrations fail
set +e

echo "🚀 Starting Laravel application setup..."
echo "📋 Checking environment variables..."

# Debug: Show what database variables are available
echo "DB_HOST: ${DB_HOST:-'not set'}"
echo "DB_DATABASE: ${DB_DATABASE:-'not set'}"
echo "DB_USERNAME: ${DB_USERNAME:-'not set'}"
echo "MYSQLHOST: ${MYSQLHOST:-'not set'}"
echo "MYSQLDATABASE: ${MYSQLDATABASE:-'not set'}"

# Change to the core directory where Laravel is installed
cd /var/www/html/core

# Set database variables from Railway if not already set
if [ -n "$MYSQLHOST" ] && [ -z "$DB_HOST" ]; then
    echo "🔧 Setting database variables from Railway..."
    export DB_CONNECTION=mysql
    export DB_HOST=$MYSQLHOST
    export DB_PORT=${MYSQLPORT:-3306}
    export DB_DATABASE=$MYSQLDATABASE
    export DB_USERNAME=$MYSQLUSER
    export DB_PASSWORD=$MYSQLPASSWORD
    echo "✅ Database variables set"
fi

# Run database migrations if database is configured
if [ -n "$DB_HOST" ] && [ -n "$DB_DATABASE" ]; then
    echo "📦 Running database migrations..."
    php artisan migrate --force --no-interaction 2>&1 || echo "⚠️  Migration warning: Some migrations may have failed"
    echo "✅ Migration step completed"
else
    echo "⚠️  Database not configured, skipping migrations"
    echo "💡 Make sure to set DB_HOST and DB_DATABASE in Railway variables"
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
