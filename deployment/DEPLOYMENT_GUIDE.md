# ProChat Staging Deployment Guide

## Prerequisites

- Ubuntu ARM64 server with nginx installed
- Domain A record configured: `prochat.progressnet.io`
- PostgreSQL database
- SSH access to the server

## Initial Server Setup

### 1. Install Required Packages

```bash
sudo apt update
sudo apt install -y postgresql nginx certbot python3-certbot-nginx
```

### 2. Create Mattermost User

```bash
sudo useradd --system --user-group --home-dir /opt/mattermost mattermost
```

### 3. Setup PostgreSQL Database

```bash
sudo -u postgres psql
```

```sql
CREATE DATABASE mattermost;
CREATE USER mmuser WITH PASSWORD 'your_secure_password';
GRANT ALL PRIVILEGES ON DATABASE mattermost TO mmuser;
\q
```

### 4. Install Systemd Service

```bash
sudo cp deployment/mattermost.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable mattermost
```

### 5. Configure Nginx

```bash
sudo cp deployment/nginx-prochat.conf /etc/nginx/sites-available/prochat
sudo ln -s /etc/nginx/sites-available/prochat /etc/nginx/sites-enabled/
sudo rm /etc/nginx/sites-enabled/default  # Remove default site
```

### 6. Setup SSL Certificate

```bash
sudo certbot --nginx -d prochat.progressnet.io
```

The certbot will automatically modify the nginx config to use the generated certificates.

### 7. Configure Mattermost

Create `/opt/mattermost/config/config.json`:

```json
{
  "ServiceSettings": {
    "SiteURL": "https://prochat.progressnet.io",
    "ListenAddress": ":8065"
  },
  "SqlSettings": {
    "DriverName": "postgres",
    "DataSource": "postgres://mmuser:your_secure_password@localhost:5432/mattermost?sslmode=disable&connect_timeout=10"
  }
}
```

Adjust permissions:

```bash
sudo chown -R mattermost:mattermost /opt/mattermost
sudo chmod 600 /opt/mattermost/config/config.json
```

## GitHub Actions Setup

The CI/CD workflow uses a **pull-based deployment** approach:

1. GitHub Actions builds the application and creates a GitHub Release
2. Your server pulls the latest release from GitHub using a deployment script

This approach avoids firewall issues with SSH from GitHub Actions runners.

## Deployment Workflow

### How it works:

1. **GitHub Actions** (automatic on push to `master`):
   - Builds the webapp
   - Builds the Go server for ARM64
   - Creates a GitHub Release with the build artifact

2. **On your server** (manual or automated):
   - Run the deployment script to pull and deploy the latest release

### Deploy on Server

Copy the deployment script to your server:

```bash
# On your server
curl -o deploy.sh https://raw.githubusercontent.com/YOUR_USERNAME/prochat/master/deployment/deploy-from-github.sh
chmod +x deploy.sh
```

Update `GITHUB_REPO` variable in the script with your repository.

Run deployment:

```bash
sudo ./deploy.sh
```

### Automated Deployment (Optional)

To automatically deploy when a new release is created, set up a cron job or use GitHub webhooks.

Example cron (check every 5 minutes):

```bash
*/5 * * * * /home/your-user/deploy.sh >> /var/log/prochat-deploy.log 2>&1
```

## Server Management Commands

```bash
# Start Mattermost
sudo systemctl start mattermost

# Stop Mattermost
sudo systemctl stop mattermost

# Restart Mattermost
sudo systemctl restart mattermost

# Check status
sudo systemctl status mattermost

# View logs
sudo journalctl -u mattermost -f

# Test nginx config
sudo nginx -t

# Reload nginx
sudo systemctl reload nginx
```

## Rollback Procedure

The deployment script creates automatic backups. To rollback:

```bash
# List backups
ls -lt /opt/mattermost.backup.*

# Restore from backup
sudo systemctl stop mattermost
sudo rm -rf /opt/mattermost
sudo mv /opt/mattermost.backup.YYYYMMDD-HHMMSS /opt/mattermost
sudo chown -R mattermost:mattermost /opt/mattermost
sudo systemctl start mattermost
```

## Monitoring

### Check Application Health

```bash
curl https://prochat.progressnet.io/api/v4/system/ping
```

### Database Connection

```bash
sudo -u postgres psql -d mattermost -c "SELECT COUNT(*) FROM users;"
```

### Disk Space

```bash
df -h /opt/mattermost
```

## Troubleshooting

### Service won't start

```bash
sudo journalctl -u mattermost -n 50
```

### Database connection issues

Check PostgreSQL is running:
```bash
sudo systemctl status postgresql
```

Test connection:
```bash
psql -h localhost -U mmuser -d mattermost
```

### Nginx errors

```bash
sudo nginx -t
sudo tail -f /var/log/nginx/error.log
```

### Permission issues

```bash
sudo chown -R mattermost:mattermost /opt/mattermost
sudo chmod -R 755 /opt/mattermost
sudo chmod 600 /opt/mattermost/config/config.json
```
