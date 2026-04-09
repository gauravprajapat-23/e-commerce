#!/bin/bash

# Don't exit on error - we want Apache to start even if migrations fail
set +e

echo "🚀 Starting Laravel application setup..."
echo "📋 Checking environment variables..."

echo "DB_HOST: ${DB_HOST:-'not set'}"
echo "DB_DATABASE: ${DB_DATABASE:-'not set'}"
echo "DB_USERNAME: ${DB_USERNAME:-'not set'}"
echo "MYSQLHOST: ${MYSQLHOST:-'not set'}"
echo "MYSQL_HOST: ${MYSQL_HOST:-'not set'}"
echo "MYSQLDATABASE: ${MYSQLDATABASE:-'not set'}"
echo "MYSQL_DATABASE: ${MYSQL_DATABASE:-'not set'}"

decode_placeholder() {
  local value="$1"
  if [[ "$value" =~ ^\$\{\{?([A-Za-z_][A-Za-z0-9_]*)\}\}?$ ]]; then
    local var_name="${BASH_REMATCH[1]}"
    local resolved=""
    local candidates=("$var_name" "${var_name//_/}" )
    for candidate in "${candidates[@]}"; do
      if [ -n "${!candidate:-}" ]; then
        resolved="${!candidate}"
        break
      fi
    done
    printf '%s' "$resolved"
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
  elif [ -z "$current_value" ]; then
    if [ -n "$rail_value" ]; then
      export "$app_var"="$rail_value"
    fi
  fi
}

resolve_db_var DB_HOST MYSQLHOST
resolve_db_var DB_HOST MYSQL_HOST
resolve_db_var DB_PORT MYSQLPORT
resolve_db_var DB_PORT MYSQL_PORT
resolve_db_var DB_DATABASE MYSQLDATABASE
resolve_db_var DB_DATABASE MYSQL_DATABASE
resolve_db_var DB_USERNAME MYSQLUSER
resolve_db_var DB_USERNAME MYSQL_USER
resolve_db_var DB_PASSWORD MYSQLPASSWORD
resolve_db_var DB_PASSWORD MYSQL_PASSWORD

echo "Resolved DB_HOST: ${DB_HOST:-'not set'}"
echo "Resolved DB_DATABASE: ${DB_DATABASE:-'not set'}"
echo "Resolved DB_USERNAME: ${DB_USERNAME:-'not set'}"

echo "Raw MYSQLHOST: ${MYSQLHOST:-'not set'}"
echo "Raw MYSQL_HOST: ${MYSQL_HOST:-'not set'}"
echo "Raw MYSQLDATABASE: ${MYSQLDATABASE:-'not set'}"
echo "Raw MYSQL_DATABASE: ${MYSQL_DATABASE:-'not set'}"

echo "Raw DB_HOST value: ${DB_HOST:-'not set'}"

echo "Raw DB_DATABASE value: ${DB_DATABASE:-'not set'}"

# Change to the core directory where Laravel is installed
cd /var/www/html/core

if [ -n "$DB_HOST" ] && [ -n "$DB_DATABASE" ] && [[ ! "$DB_HOST" =~ ^\$\{ ]]; then
    echo "📦 Running database migrations..."
    php artisan migrate --force --no-interaction 2>&1 || echo "⚠️  Migration warning: Some migrations may have failed"
    echo "✅ Migration step completed"

    echo "🔧 Optimizing Laravel..."
    php artisan config:cache 2>&1 || echo "⚠️  Config cache warning"
    php artisan route:cache 2>&1 || echo "⚠️  Route cache warning"
    php artisan view:cache 2>&1 || echo "⚠️  View cache warning"
    echo "✅ Laravel optimization completed"
else
    echo "⚠️  Database not configured or DB_HOST unresolved, skipping migrations and cache generation"
    echo "💡 Current DB_HOST: ${DB_HOST:-'not set'}"
    echo "💡 Current DB_DATABASE: ${DB_DATABASE:-'not set'}"
fi

# Ensure proper permissions
echo "🔒 Setting permissions..."
chown -R www-data:www-data /var/www/html/core/storage /var/www/html/core/bootstrap/cache 2>&1 || true
chmod -R 775 /var/www/html/core/storage /var/www/html/core/bootstrap/cache 2>&1 || true
echo "✅ Permissions set"

# Ensure only one MPM is enabled
a2dismod mpm_event mpm_worker mpm_async 2>/dev/null || true
a2enmod mpm_prefork 2>/dev/null || true

# Start Apache
echo "🌐 Starting Apache web server..."
exec apache2-foreground
