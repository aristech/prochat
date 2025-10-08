#!/bin/bash
# ProChat Server Initial Setup Script
# Run this once to set up the server

set -e

echo "==> Creating mattermost user..."
sudo useradd --system --user-group --home-dir /opt/mattermost mattermost || echo "User already exists"

echo "==> Setting up systemd service..."
sudo tee /etc/systemd/system/mattermost.service > /dev/null <<'EOF'
[Unit]
Description=Mattermost (ProChat)
After=network.target postgresql.service

[Service]
Type=simple
User=mattermost
Group=mattermost
WorkingDirectory=/opt/mattermost
ExecStart=/opt/mattermost/bin/mattermost
Restart=always
RestartSec=10
LimitNOFILE=49152

[Install]
WantedBy=multi-user.target
EOF

echo "==> Reloading systemd..."
sudo systemctl daemon-reload

echo "==> Enabling mattermost service..."
sudo systemctl enable mattermost

echo "==> Creating directories..."
sudo mkdir -p /opt/mattermost/config
sudo mkdir -p /opt/mattermost/data
sudo mkdir -p /opt/mattermost/logs
sudo mkdir -p /opt/mattermost/plugins

echo "==> Setting permissions..."
sudo chown -R mattermost:mattermost /opt/mattermost

echo ""
echo "✅ Server setup complete!"
echo ""
echo "Next steps:"
echo "1. Configure your database (PostgreSQL)"
echo "2. Create /opt/mattermost/config/config.json (see DEPLOYMENT_GUIDE.md)"
echo "3. Run ./deploy-from-github.sh to deploy the application"
