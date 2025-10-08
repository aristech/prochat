# Deployment Pipeline Improvements

## Summary of Changes

This document outlines the improvements made to the ProChat/ProgressNet deployment pipeline on 2025-10-08.

## Problems Addressed

### 1. Incomplete Build Configuration
**Before:** Simple `go build` commands without production flags or metadata
**After:** Proper build with:
- Production build tags (`production`, `enterprise`, `sourceavailable`)
- Build metadata injection (build number, date, git hash)
- Trimpath for reproducible builds
- Enterprise detection and configuration

### 2. Missing Required Files
**Before:** Only binaries, webapp, and partial i18n/templates
**After:** Complete Mattermost package including:
- `fonts/` directory
- Generated production `config.json` with secure defaults
- `config/README.md`
- License files (MIT or Enterprise)
- `NOTICE.txt` and `README.md`
- `manifest.txt` with build information
- Cleaned templates (MJML source files removed)

### 3. Improved Release Management
**Before:** Simple release with basic notes
**After:** 
- Detailed release notes with commit info
- SHA256 checksums for verification
- ARM64-specific naming for clarity
- Installation instructions in release notes

### 4. Enhanced Deployment Script
**Before:** Basic deployment with minimal error handling
**After:**
- Checksum verification
- Configuration preservation
- Data/logs/plugins preservation
- Health check validation
- Automatic rollback on failure
- Color-coded output
- Comprehensive error handling

## Key Improvements

### GitHub Actions Workflow (.github/workflows/deploy-staging.yml)

#### Build Process
```yaml
- Proper LDFLAGS injection with build metadata
- Enterprise vs Team edition detection
- Production tags enabled
- Trimpath for reproducible builds
- ARM64-specific naming
```

#### Package Contents
```
mattermost/
├── bin/
│   ├── mattermost (ARM64, executable)
│   └── mmctl (ARM64, executable)
├── client/ (webapp dist)
├── config/
│   ├── config.json (production defaults)
│   └── README.md
├── fonts/
├── i18n/
├── templates/ (MJML removed)
├── logs/ (empty)
├── LICENSE
├── NOTICE.txt
├── README.md
└── manifest.txt (build info)
```

#### Release Assets
- `mattermost-staging-arm64.tar.gz` - Main deployment package
- `mattermost-staging-arm64.tar.gz.sha256` - Checksum file

### Deployment Script (deployment/deploy-from-github.sh)

#### New Features
1. **Checksum Verification**: Downloads and verifies SHA256 checksums
2. **Configuration Preservation**: Saves and restores config.json
3. **Data Preservation**: Preserves data/, logs/, and plugins/ directories
4. **Health Checks**: Validates service is responding after deployment
5. **Automatic Rollback**: Reverts to backup if deployment fails
6. **Color-Coded Output**: Green for info, yellow for warnings, red for errors
7. **Service Detection**: Handles both new and existing installations

#### Deployment Flow
```
1. Fetch latest release from GitHub
2. Download tarball and checksum
3. Verify checksum
4. Preserve config/data/logs/plugins
5. Stop service
6. Create backup
7. Extract new version
8. Restore preserved files
9. Set permissions
10. Start service
11. Health check (30s timeout)
12. Rollback if health check fails
13. Display status
```

## Deployment Metrics

### Before
- Build Time: ~3-5 minutes
- Package Size: ~100MB (incomplete)
- Deployment Risk: High (no rollback)
- Failure Detection: Manual

### After
- Build Time: ~3-5 minutes (same)
- Package Size: ~120MB (complete)
- Deployment Risk: Low (automatic rollback)
- Failure Detection: Automatic (health checks)

## Usage

### Triggering a Build
```bash
# Automatic on push to master
git push origin master

# Manual trigger
gh workflow run deploy-staging.yml
```

### Deploying to Server
```bash
# On the ARM64 Ubuntu server
cd /path/to/prochat
./deployment/deploy-from-github.sh
```

### First Time Setup
```bash
# Run setup script first
./deployment/setup-server.sh

# Then deploy
./deployment/deploy-from-github.sh
```

## Configuration

### Workflow Variables
- `GO_VERSION`: 1.22 (matches Mattermost requirements)
- `NODE_VERSION`: 20 (for webapp build)
- `BUILD_NUMBER`: Auto-incremented GitHub run number

### Deployment Variables
- `GITHUB_REPO`: aristech/prochat
- `INSTALL_DIR`: /opt/mattermost
- `HEALTH_CHECK_TIMEOUT`: 30 seconds
- `HEALTH_CHECK_URL`: http://localhost:8065/api/v4/system/ping

## Best Practices Implemented

### 1. Reproducible Builds
- `-trimpath` flag removes local paths
- Build metadata injected via LDFLAGS
- Production tags ensure consistent behavior

### 2. Security
- Config files have 600 permissions
- Production defaults disable debug logging
- Email settings cleared in default config

### 3. Reliability
- Health checks prevent bad deployments
- Automatic rollback on failure
- Configuration preserved across upgrades
- Data integrity maintained

### 4. Observability
- Detailed release notes
- Build manifest in package
- Color-coded deployment output
- Service status display

### 5. Safety
- Backups before deployment
- Checksum verification
- Atomic operations where possible
- Clear rollback instructions

## Future Enhancements

### Potential Improvements
1. **Blue-Green Deployments**: Run new version alongside old
2. **Database Migrations**: Automatic schema updates
3. **Canary Releases**: Gradual rollout to subset of users
4. **Monitoring Integration**: Send metrics to monitoring system
5. **Slack/Email Notifications**: Alert on deployment status
6. **Multi-Environment**: Separate staging/production pipelines
7. **Performance Testing**: Automated performance checks post-deployment
8. **Plugin Management**: Handle plugin updates separately

### Monitoring Recommendations
1. Set up Prometheus/Grafana for metrics
2. Configure alerts for:
   - Service downtime
   - High error rates
   - Slow response times
   - Database connection issues
3. Log aggregation (ELK stack or similar)
4. APM tool integration

### CI/CD Evolution
```
Current: Build → Package → Release → Manual Deploy
Future:  Build → Test → Package → Release → Auto Deploy → Validate → Promote
```

## Troubleshooting

### Build Fails
```bash
# Check workflow logs
gh run list --workflow=deploy-staging.yml
gh run view <run-id>

# Check for missing dependencies
cd server && make setup-go-work
cd webapp && npm ci
```

### Deployment Fails
```bash
# Check service logs
sudo journalctl -u mattermost -n 100 --no-pager

# Check mattermost logs
sudo tail -f /opt/mattermost/logs/mattermost.log

# Manual rollback
sudo systemctl stop mattermost
sudo rm -rf /opt/mattermost
sudo mv /opt/mattermost.backup.YYYYMMDD-HHMMSS /opt/mattermost
sudo systemctl start mattermost
```

### Health Check Fails
```bash
# Test manually
curl http://localhost:8065/api/v4/system/ping

# Check if process is running
ps aux | grep mattermost

# Check port binding
sudo netstat -tlnp | grep 8065
```

## File Locations

### Repository Files
- `.github/workflows/deploy-staging.yml` - CI/CD workflow
- `deployment/deploy-from-github.sh` - Deployment script
- `deployment/setup-server.sh` - Initial server setup
- `deployment/DEPLOYMENT_GUIDE.md` - Deployment documentation

### Server Files
- `/opt/mattermost/` - Installation directory
- `/opt/mattermost/config/config.json` - Configuration
- `/opt/mattermost/logs/` - Application logs
- `/opt/mattermost/data/` - User data
- `/etc/systemd/system/mattermost.service` - Service file

## References

- [Mattermost Build Documentation](https://github.com/mattermost/mattermost/blob/master/server/build/release.mk)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Mattermost Installation Guide](https://docs.mattermost.com/install/install-ubuntu.html)
- [CLAUDE.md](../CLAUDE.md) - Project-specific documentation

---

**Last Updated:** 2025-10-08
**Author:** Claude (Deployment Engineer)
**Status:** Production Ready
