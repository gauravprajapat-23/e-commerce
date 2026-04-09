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

# ---------------------------------------------------------------
# Step 1: Directly map Railway MySQL variables to Laravel DB vars.
# Railway injects MYSQLHOST, MYSQLPORT, etc. into the environment
# of the running container. If DB_HOST is still a literal
# placeholder (e.g. "${MYSQLHOST}" or "${{MYSQLHOST}}") or is
# simply empty, override it with the Railway-provided value.
# ---------------------------------------------------------------
map_railway_var() {
  local app_var="$1"   # e.g. DB_HOST
  local rail_var="$2"  # e.g. MYSQLHOST
  local current="${!app_var:-}"
  local railway="${!rail_var:-}"

  echo "🔍 Checking ${app_var}: current='${current}' railway_source=${rail_var}='${railway}'"

  # Treat the current value as unresolved if it is empty OR if it
  # still looks like a shell/Railway variable reference.
  if [[ -z "$current" || "$current" =~ ^\$\{?\{? ]]; then
    if [ -n "$railway" ]; then
      echo "  ✅ Mapping ${rail_var}='${railway}' → ${app_var}"
      export "$app_var"="$railway"
    else
      echo "  ⚠️  ${rail_var} is also not set; ${app_var} remains unresolved"
    fi
  else
    echo "  ℹ️  ${app_var} already resolved to '${current}', keeping as-is"
  fi
}

# Map Railway MySQL service variables → Laravel DB variables
map_railway_var DB_HOST     MYSQLHOST
map_railway_var DB_HOST     MYSQL_HOST
map_railway_var DB_PORT     MYSQLPORT
map_railway_var DB_PORT     MYSQL_PORT
map_railway_var DB_DATABASE MYSQLDATABASE
map_railway_var DB_DATABASE MYSQL_DATABASE
map_railway_var DB_USERNAME MYSQLUSER
map_railway_var DB_USERNAME MYSQL_USER
map_railway_var DB_PASSWORD MYSQLPASSWORD
map_railway_var DB_PASSWORD MYSQL_PASSWORD

echo ""
echo "📊 Resolved database configuration:"
echo "  DB_HOST:     ${DB_HOST:-'not set'}"
echo "  DB_PORT:     ${DB_PORT:-'not set'}"
echo "  DB_DATABASE: ${DB_DATABASE:-'not set'}"
echo "  DB_USERNAME: ${DB_USERNAME:-'not set'}"
echo "  DB_PASSWORD: ${DB_PASSWORD:+'(set)'}"

# Change to the core directory where Laravel is installed
cd /var/www/html/core

# ---------------------------------------------------------------
# Step 2: Determine whether the database is reachable enough to
# attempt migrations.  We consider the DB available when DB_HOST
# is set AND does not still contain an unresolved placeholder.
# As a fallback, if MYSQLHOST is set we also try — this covers
# the edge case where DB_HOST resolution above still failed.
# ---------------------------------------------------------------
DB_AVAILABLE=false

if [ -n "$DB_HOST" ] && [[ ! "$DB_HOST" =~ ^\$\{ ]]; then
    DB_AVAILABLE=true
    echo "✅ DB_HOST resolved to '${DB_HOST}', will attempt migrations"
elif [ -n "$MYSQLHOST" ]; then
    # Last-resort: export directly and try anyway
    export DB_HOST="$MYSQLHOST"
    [ -n "$MYSQLPORT" ]     && export DB_PORT="$MYSQLPORT"
    [ -n "$MYSQLDATABASE" ] && export DB_DATABASE="$MYSQLDATABASE"
    [ -n "$MYSQLUSER" ]     && export DB_USERNAME="$MYSQLUSER"
    [ -n "$MYSQLPASSWORD" ] && export DB_PASSWORD="$MYSQLPASSWORD"
    DB_AVAILABLE=true
    echo "✅ Fell back to MYSQLHOST='${MYSQLHOST}', will attempt migrations"
fi

if [ "$DB_AVAILABLE" = true ] && [ -n "$DB_DATABASE" ]; then
    echo "📦 Running database migrations..."
    php artisan migrate --force --no-interaction 2>&1 \
        || echo "⚠️  Migration warning: Some migrations may have failed (non-fatal)"
    echo "✅ Migration step completed"

    echo "🔧 Optimizing Laravel..."
    php artisan config:cache 2>&1  || echo "⚠️  Config cache warning (non-fatal)"
    php artisan route:cache 2>&1   || echo "⚠️  Route cache warning (non-fatal)"
    php artisan view:cache 2>&1    || echo "⚠️  View cache warning (non-fatal)"
    echo "✅ Laravel optimization completed"
else
    echo "⚠️  Database not configured — skipping migrations and cache generation"
    echo "💡 DB_HOST:     ${DB_HOST:-'not set'}"
    echo "💡 DB_DATABASE: ${DB_DATABASE:-'not set'}"
    echo "💡 MYSQLHOST:   ${MYSQLHOST:-'not set'}"
fi

# Ensure proper permissions
echo "🔒 Setting permissions..."
chown -R www-data:www-data /var/www/html/core/storage /var/www/html/core/bootstrap/cache 2>&1 || true
chmod -R 775 /var/www/html/core/storage /var/www/html/core/bootstrap/cache 2>&1 || true
echo "✅ Permissions set"

# Ensure only one MPM is enabled
a2dismod mpm_event mpm_worker mpm_async 2>/dev/null || true
a2enmod mpm_prefork 2>/dev/null || true

# ---------------------------------------------------------------
# Step 3: Configure Apache to listen on the PORT variable from Railway
# Railway injects PORT env variable and health checks use this port
# Default to 80 if PORT is not set
# ---------------------------------------------------------------
APACHE_PORT=${PORT:-80}
echo "🔧 Configuring Apache to listen on port: ${APACHE_PORT}"

# Update Apache ports.conf to use the PORT variable
sed -i "s/Listen 80/Listen ${APACHE_PORT}/g" /etc/apache2/ports.conf
sed -i "s/Listen 80/Listen ${APACHE_PORT}/g" /etc/apache2/sites-available/000-default.conf

echo "🌐 Starting Apache web server on port ${APACHE_PORT}..."
apache2-foreground
