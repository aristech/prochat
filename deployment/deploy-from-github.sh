#!/bin/bash
# ProChat Deployment Script - Pull from GitHub Releases
# Run this on your staging server to deploy the latest build

set -e

GITHUB_REPO="aristech/prochat"  # Update with your GitHub username/repo
INSTALL_DIR="/opt/mattermost"
BACKUP_DIR="/opt/mattermost.backup.$(date +%Y%m%d-%H%M%S)"

echo "==> Fetching latest staging release from GitHub..."
LATEST_RELEASE=$(curl -s "https://api.github.com/repos/$GITHUB_REPO/releases" | \
  grep -m 1 '"tag_name":.*staging-' | \
  cut -d '"' -f 4)

if [ -z "$LATEST_RELEASE" ]; then
  echo "Error: No staging release found"
  exit 1
fi

echo "==> Found release: $LATEST_RELEASE"

DOWNLOAD_URL="https://github.com/$GITHUB_REPO/releases/download/$LATEST_RELEASE/mattermost-staging.tar.gz"

echo "==> Downloading build..."
curl -L -o /tmp/mattermost-staging.tar.gz "$DOWNLOAD_URL"

echo "==> Stopping mattermost service..."
sudo systemctl stop mattermost || true

echo "==> Creating backup..."
if [ -d "$INSTALL_DIR" ]; then
  sudo cp -r "$INSTALL_DIR" "$BACKUP_DIR"
  echo "Backup created at: $BACKUP_DIR"
fi

echo "==> Extracting new version..."
sudo mkdir -p "$INSTALL_DIR"
sudo tar -xzf /tmp/mattermost-staging.tar.gz -C /opt/

echo "==> Setting permissions..."
sudo chown -R mattermost:mattermost "$INSTALL_DIR"

echo "==> Starting mattermost service..."
sudo systemctl start mattermost

echo "==> Cleanup..."
rm /tmp/mattermost-staging.tar.gz

echo "==> Deployment complete!"
echo "==> Checking service status..."
sleep 3
sudo systemctl status mattermost --no-pager

echo ""
echo "Deployment finished successfully!"
echo "Release: $LATEST_RELEASE"
echo "Backup: $BACKUP_DIR"
