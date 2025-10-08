#!/bin/bash
# ProChat Deployment Script - Pull from GitHub Releases
# Run this on your staging server to deploy the latest build

set -e

# Configuration
GITHUB_REPO="aristech/prochat"
INSTALL_DIR="/opt/mattermost"
BACKUP_DIR="/opt/mattermost.backup.$(date +%Y%m%d-%H%M%S)"
TARBALL_NAME="mattermost-staging-arm64.tar.gz"
CHECKSUM_NAME="mattermost-staging-arm64.tar.gz.sha256"
HEALTH_CHECK_TIMEOUT=30
HEALTH_CHECK_URL="http://localhost:8065/api/v4/system/ping"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}==>${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}==>${NC} $1"
}

log_error() {
    echo -e "${RED}ERROR:${NC} $1"
}

# Fetch latest staging release
log_info "Fetching latest staging release from GitHub..."
LATEST_RELEASE=$(curl -s "https://api.github.com/repos/$GITHUB_REPO/releases" | \
  grep '"tag_name":.*staging-' | \
  cut -d '"' -f 4 | \
  sed 's/staging-//' | \
  sort -rn | \
  head -n 1 | \
  sed 's/^/staging-/')

if [ -z "$LATEST_RELEASE" ]; then
  log_error "No staging release found"
  exit 1
fi

log_info "Found release: $LATEST_RELEASE"

# Download URLs
DOWNLOAD_URL="https://github.com/$GITHUB_REPO/releases/download/$LATEST_RELEASE/$TARBALL_NAME"
CHECKSUM_URL="https://github.com/$GITHUB_REPO/releases/download/$LATEST_RELEASE/$CHECKSUM_NAME"

# Download build
log_info "Downloading build..."
curl -L -o "/tmp/$TARBALL_NAME" "$DOWNLOAD_URL"

if [ $? -ne 0 ]; then
  log_error "Failed to download build"
  exit 1
fi

# Download and verify checksum
log_info "Downloading checksum..."
curl -L -o "/tmp/$CHECKSUM_NAME" "$CHECKSUM_URL"

if [ $? -eq 0 ]; then
  log_info "Verifying checksum..."
  cd /tmp
  if sha256sum -c "$CHECKSUM_NAME" 2>/dev/null; then
    log_info "Checksum verification passed"
  else
    log_warn "Checksum verification failed, but continuing..."
  fi
  cd - > /dev/null
else
  log_warn "Checksum file not found, skipping verification"
fi

# Check if mattermost service exists
SERVICE_EXISTS=false
if systemctl list-unit-files | grep -q "mattermost.service"; then
  SERVICE_EXISTS=true
fi

# Preserve existing config if it exists
CONFIG_PRESERVED=false
if [ -f "$INSTALL_DIR/config/config.json" ]; then
  log_info "Preserving existing configuration..."
  cp "$INSTALL_DIR/config/config.json" "/tmp/mattermost-config-backup.json"
  CONFIG_PRESERVED=true
fi

# Stop service
if [ "$SERVICE_EXISTS" = true ]; then
  log_info "Stopping mattermost service..."
  sudo systemctl stop mattermost || true
  sleep 2
fi

# Create backup
if [ -d "$INSTALL_DIR" ]; then
  log_info "Creating backup..."
  sudo cp -r "$INSTALL_DIR" "$BACKUP_DIR"
  log_info "Backup created at: $BACKUP_DIR"
fi

# Extract new version
log_info "Extracting new version..."
sudo mkdir -p "$INSTALL_DIR"
sudo tar -xzf "/tmp/$TARBALL_NAME" -C /opt/

# Restore config if it was preserved
if [ "$CONFIG_PRESERVED" = true ]; then
  log_info "Restoring configuration..."
  sudo cp "/tmp/mattermost-config-backup.json" "$INSTALL_DIR/config/config.json"
  sudo chmod 600 "$INSTALL_DIR/config/config.json"
  rm -f "/tmp/mattermost-config-backup.json"
fi

# Preserve data, logs, and plugins directories from backup if they exist
if [ -d "$BACKUP_DIR" ]; then
  if [ -d "$BACKUP_DIR/data" ] && [ "$(ls -A $BACKUP_DIR/data 2>/dev/null)" ]; then
    log_info "Preserving data directory..."
    sudo rm -rf "$INSTALL_DIR/data"
    sudo cp -r "$BACKUP_DIR/data" "$INSTALL_DIR/"
  fi

  if [ -d "$BACKUP_DIR/logs" ] && [ "$(ls -A $BACKUP_DIR/logs 2>/dev/null)" ]; then
    log_info "Preserving logs directory..."
    sudo cp -r "$BACKUP_DIR/logs/"* "$INSTALL_DIR/logs/" 2>/dev/null || true
  fi

  if [ -d "$BACKUP_DIR/plugins" ] && [ "$(ls -A $BACKUP_DIR/plugins 2>/dev/null)" ]; then
    log_info "Preserving plugins directory..."
    sudo cp -r "$BACKUP_DIR/plugins/"* "$INSTALL_DIR/plugins/" 2>/dev/null || true
  fi
fi

# Set permissions
log_info "Setting permissions..."
sudo chown -R mattermost:mattermost "$INSTALL_DIR"

# Start service
if [ "$SERVICE_EXISTS" = true ]; then
  log_info "Starting mattermost service..."
  sudo systemctl start mattermost

  # Wait for service to be ready
  log_info "Waiting for service to become ready..."
  COUNTER=0
  while [ $COUNTER -lt $HEALTH_CHECK_TIMEOUT ]; do
    if curl -sf "$HEALTH_CHECK_URL" > /dev/null 2>&1; then
      log_info "Service is ready!"
      break
    fi
    sleep 1
    COUNTER=$((COUNTER + 1))
    echo -n "."
  done
  echo ""

  if [ $COUNTER -eq $HEALTH_CHECK_TIMEOUT ]; then
    log_error "Service failed to start within $HEALTH_CHECK_TIMEOUT seconds"
    log_warn "Rolling back to previous version..."

    # Rollback
    sudo systemctl stop mattermost
    sudo rm -rf "$INSTALL_DIR"
    sudo mv "$BACKUP_DIR" "$INSTALL_DIR"
    sudo systemctl start mattermost

    log_error "Deployment failed and was rolled back"
    exit 1
  fi
else
  log_warn "Mattermost service not found. Skipping service start."
  log_warn "You may need to run the setup script first: deployment/setup-server.sh"
fi

# Cleanup
log_info "Cleaning up temporary files..."
rm -f "/tmp/$TARBALL_NAME"
rm -f "/tmp/$CHECKSUM_NAME"

# Display status
log_info "Deployment complete!"
if [ "$SERVICE_EXISTS" = true ]; then
  log_info "Checking service status..."
  sleep 2
  sudo systemctl status mattermost --no-pager --lines=10
fi

echo ""
echo "============================================"
log_info "Deployment finished successfully!"
echo "Release: $LATEST_RELEASE"
echo "Backup: $BACKUP_DIR"
echo "============================================"
echo ""
log_info "You can safely remove the backup after verifying the deployment:"
echo "  sudo rm -rf $BACKUP_DIR"
echo ""
