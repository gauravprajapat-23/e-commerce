#!/bin/bash

# Don't exit on error - we want Apache to start even if migrations fail
set +e

echo "🚀 Starting Laravel application setup..."
echo "📋 Checking environment variables..."

echo "DB_HOST: ${DB_HOST:-'not set'}"
echo "DB_DATABASE: ${DB_DATABASE:-'not set'}"
echo "DB_USERNAME: ${DB_USERNAME:-'not set'}"
echo "MYSQLHOST: ${MYSQLHOST:-'not set'}"
echo "MYSQLDATABASE: ${MYSQLDATABASE:-'not set'}"

decode_placeholder() {
  local value="$1"
  if [[ "$value" =~ ^\$\{([A-Za-z_][A-Za-z0-9_]*)\}$ ]]; then
    local var_name="${BASH_REMATCH[1]}"
    printf '%s' "${!var_name:-}"
  else
    printf '%s' "$value"
  fi
}

resolve_db_var() {
  local app_var="$1"
  local rail_var="$2"
  local current_value="${!app_var:-}"
  local rail_value="${!rail_var:-}"
  local decoded_value="$(decode_placeholder "$current_value")"

  if [ -n "$decoded_value" ] && [ "$decoded_value" != "$current_value" ]; then
    export "$app_var"="$decoded_value"
  elif [ -z "$current_value" ] && [ -n "$rail_value" ]; then
    export "$app_var"="$rail_value"
  fi
}

resolve_db_var DB_HOST MYSQLHOST
resolve_db_var DB_PORT MYSQLPORT
resolve_db_var DB_DATABASE MYSQLDATABASE
resolve_db_var DB_USERNAME MYSQLUSER
resolve_db_var DB_PASSWORD MYSQLPASSWORD

# Change to the core directory where Laravel is installed
cd /var/www/html/core

if [ -n "$DB_HOST" ] && [ -n "$DB_DATABASE" ]; then
    echo "📦 Running database migrations..."
    php artisan migrate --force --no-interaction 2>&1 || echo "⚠️  Migration warning: Some migrations may have failed"
    echo "✅ Migration step completed"
else
    echo "⚠️  Database not configured, skipping migrations"
    echo "💡 Make sure DB_HOST and DB_DATABASE are set correctly in Railway variables"
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
