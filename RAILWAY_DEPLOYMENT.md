# Railway Deployment Guide for Laravel E-Commerce

## Prerequisites

1. Railway account (https://railway.app)
2. Railway CLI installed (optional but recommended)
3. Git repository with your code

## Deployment Steps

### 1. Prepare Your Repository

Ensure these files are in your repository root:
- ✅ `Dockerfile` - Production-ready Docker configuration
- ✅ `railway.json` - Railway deployment configuration
- ✅ `start.sh` - Application startup script
- ✅ `.dockerignore` - Exclude unnecessary files from Docker build
- ✅ `core/.env.example` - Clean environment template

### 2. Set Up Railway Project

1. Go to https://railway.app and create a new project
2. Click "Deploy from GitHub repo" and select your repository
3. Railway will automatically detect the `railway.json` and `Dockerfile`

### 3. Add MySQL Database

1. In your Railway project, click "+ New"
2. Select "Database" → "Add MySQL"
3. Wait for the database to provision
4. Railway will automatically create environment variables:
   - `MYSQLHOST`
   - `MYSQLPORT`
   - `MYSQLDATABASE`
   - `MYSQLUSER`
   - `MYSQLPASSWORD`

### 4. Configure Environment Variables

In Railway, go to your service → Variables tab and add:

```bash
# Application
APP_NAME="Your E-Commerce Store"
APP_ENV=production
APP_KEY=base64:YOUR_GENERATED_KEY_HERE
APP_DEBUG=false
APP_URL=https://your-domain.railway.app

# Database (Railway auto-generates these, but you can override if needed)
DB_CONNECTION=mysql
DB_HOST=${{MYSQLHOST}}
DB_PORT=${{MYSQLPORT}}
DB_DATABASE=${{MYSQLDATABASE}}
DB_USERNAME=${{MYSQLUSER}}
DB_PASSWORD=${{MYSQLPASSWORD}}

# Session & Cache
SESSION_DRIVER=database
CACHE_STORE=database
QUEUE_CONNECTION=database

# Mail (Configure your email provider)
MAIL_MAILER=smtp
MAIL_HOST=your-smtp-host
MAIL_PORT=587
MAIL_USERNAME=your-email
MAIL_PASSWORD=your-password
MAIL_ENCRYPTION=tls
MAIL_FROM_ADDRESS=noreply@yourdomain.com
MAIL_FROM_NAME="${APP_NAME}"

# Logging
LOG_CHANNEL=stderr
LOG_LEVEL=error
```

### 5. Generate APP_KEY

Run this command locally or in Railway shell:
```bash
php artisan key:generate --show
```

Copy the output and set it as `APP_KEY` in Railway variables.

### 6. Deploy

1. Push your code to GitHub
2. Railway will automatically build and deploy
3. Monitor the deployment logs in Railway dashboard

### 7. Post-Deployment

After first deployment:

1. **Access Railway Shell** (in dashboard):
   ```bash
   cd /var/www/html/core
   php artisan migrate --force
   php artisan db:seed --force  # If you have seeders
   php artisan storage:link
   ```

2. **Set up a custom domain** (optional):
   - Go to Settings → Domains
   - Add your custom domain
   - Update DNS records as instructed

## Important Notes

### File Storage
- The `/var/www/html/core/storage` directory is where uploads are stored
- Consider using external storage (S3, etc.) for production
- Update `FILESYSTEM_DISK` in environment variables if using cloud storage

### Queue Worker (Optional)
If you need background job processing, deploy a separate worker service:

1. Create a new service in Railway
2. Set the start command to:
   ```bash
   cd /var/www/html/core && php artisan queue:work --tries=3
   ```

### Scheduler (Optional)
For scheduled tasks, add to Railway cron or use a separate service:
```bash
* * * * * cd /var/www/html/core && php artisan schedule:run >> /dev/null 2>&1
```

### Security Checklist
- ✅ `APP_DEBUG=false` in production
- ✅ Generate unique `APP_KEY`
- ✅ Use strong database passwords (Railway provides these)
- ✅ Configure proper email settings
- ✅ Set up SSL (Railway provides this automatically)
- ✅ Regular database backups

## Troubleshooting

### Build Fails
- Check Docker build logs in Railway
- Ensure all files are committed to Git
- Verify `composer.json` and `composer.lock` are present

### Database Connection Issues
- Verify Railway MySQL service is running
- Check environment variables are correctly set
- Use Railway's built-in database variables

### Application Errors
- Check logs in Railway dashboard
- Ensure `APP_DEBUG=false` in production
- Verify all required environment variables are set

### Permission Issues
The Dockerfile handles permissions, but if needed:
```bash
chown -R www-data:www-data /var/www/html/core/storage
chmod -R 775 /var/www/html/core/storage
```

## Updating Your Application

1. Push changes to your Git repository
2. Railway will automatically redeploy
3. Migrations run automatically on startup (via `start.sh`)

## Monitoring

- Use Railway's built-in logs
- Monitor database performance
- Set up error tracking (Sentry, etc.)
- Regular backups of your database

## Support

For Railway-specific issues: https://docs.railway.app
For Laravel issues: https://laravel.com/docs