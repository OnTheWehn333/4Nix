# TAK Server Manual Setup Guide

This guide walks you through setting up TAK Server manually on your NixOS server.

## What NixOS Provides

Your NixOS configuration (`services.tak-server.enable = true`) automatically installs:

- **Docker & Docker Compose** - Container runtime
- **git** - Clone the TAK server repository
- **unzip** - Extract TAK server release
- **nettools** - Network utilities (netstat, etc.)
- **curl, wget** - Download utilities
- **Docker group membership** - No `sudo` needed for Docker commands
- **Working directory** - `/opt/tak-server` (owned by you)
- **Firewall ports** - Automatically opened (if `openFirewall = true`)

## Prerequisites

1. NixOS system with the TAK server module enabled
2. Account at https://tak.gov to download TAK Server
3. Internet connection

## Setup Steps

### 1. Rebuild NixOS Configuration

First, apply the NixOS configuration to install all tools:

```bash
# On your server-tenoko
sudo nixos-rebuild switch --flake .#server-tenoko
```

This installs Docker, docker-compose, and all required tools.

### 2. Clone TAK Server Repository

```bash
cd /opt/tak-server
git clone https://github.com/Cloud-RF/tak-server.git
cd tak-server
```

### 3. Download TAK Server Release

**Important: You must download this manually from tak.gov**

1. Go to https://tak.gov/products/tak-server
2. Register or log in
3. Download the latest release: `takserver-docker-5.5-RELEASE-58.zip` (or newer)
4. Transfer to your server:

```bash
# From your local machine
scp takserver-docker-5.5-RELEASE-58.zip noahbalboa66@server-tenoko:/opt/tak-server/tak-server/
```

### 4. Verify Checksum (Security Check)

**IMPORTANT: Always verify checksums before proceeding!**

```bash
cd /opt/tak-server/tak-server

# Check MD5
md5sum takserver-docker-5.5-RELEASE-58.zip
# Expected: 6d362f234305b9a5e8f9245ef8f3e45d

# Check SHA1
sha1sum takserver-docker-5.5-RELEASE-58.zip
# Expected: 7f0c07aa0ad7ff575c0278d734264e3e446ec93c
```

**If checksums don't match, DO NOT PROCEED!** Download again from tak.gov.

### 5. Run Setup Script

```bash
cd /opt/tak-server/tak-server
chmod +x scripts/setup.sh
./scripts/setup.sh
```

The interactive setup script will:

1. **Ask for network interface** - Choose the interface clients will connect to (e.g., `eth0`, `enp0s3`)
2. **Check ports** - Verify required ports are available
3. **Extract TAK Server** - Unzip the release
4. **Generate certificates** - Create SSL certificates
5. **Configure PostgreSQL** - Set up database
6. **Start Docker containers** - Launch TAK Server

**During setup you'll be prompted for:**
- Network interface selection
- Certificate details:
  - State (e.g., "Texas")
  - City (e.g., "Austin")
  - Organizational Unit (e.g., "TAK")
- Admin certificate name (default: "admin")

**CRITICAL: Save these passwords!** The script displays them ONCE at the end:
- **Admin username**: admin
- **Admin password**: (random, shown once)
- **PostgreSQL password**: (random, shown once)

### 6. Verify TAK Server is Running

```bash
# Check Docker containers
docker ps

# View logs
docker-compose logs -f

# Check specific services
docker logs tak-server-tak-1 -f
```

You should see containers running for:
- `tak-server-tak-1` - TAK Server
- `tak-server-db-1` - PostgreSQL database

### 7. Access Web UI

#### Import Admin Certificate

1. The admin certificate is located at:
   ```
   /opt/tak-server/tak-server/tak/certs/files/admin.p12
   ```

2. Copy to your local machine:
   ```bash
   # From your local machine
   scp noahbalboa66@server-tenoko:/opt/tak-server/tak-server/tak/certs/files/admin.p12 .
   ```

3. Import into your browser:

   **Firefox:**
   - Settings → Privacy & Security → Certificates
   - Click "View Certificates"
   - "Your Certificates" tab → Click "Import"
   - Select `admin.p12` (password: `atakatak`)
   - Go to "Authorities" tab → Find "TAK" → Select your cert
   - Click "Edit Trust" → Check "This certificate can identify web sites"

   **Chrome:**
   - Settings → Privacy and Security → Security
   - Scroll to "Manage Certificates"
   - "Your certificates" tab → Click "Import"
   - Select `admin.p12` (password: `atakatak`)

4. Access the web UI:
   ```
   https://<your-server-ip>:8443
   ```
   
   The browser will authenticate you automatically using the certificate.

## Managing TAK Server

### Start/Stop Services

```bash
cd /opt/tak-server/tak-server

# Start (in background)
docker-compose up -d

# Stop
docker-compose down

# Restart
docker-compose restart

# View status
docker-compose ps
```

### View Logs

```bash
# All services
docker-compose logs -f

# TAK Server only
docker logs tak-server-tak-1 -f

# PostgreSQL only
docker logs tak-server-db-1 -f

# TAK log file
tail -f /opt/tak-server/tak-server/tak/logs/takserver.log
```

### Access Container Shell

```bash
# TAK Server container
docker exec -it tak-server-tak-1 bash

# PostgreSQL container
docker exec -it tak-server-db-1 bash
```

### Create User Certificates

To add ATAK/iTAK clients, you need user certificates:

```bash
cd /opt/tak-server/tak-server
./scripts/setup.sh
# Follow prompts to create new user
```

User data packages (`.zip` files) are created in:
```
/opt/tak-server/tak-server/tak/certs/files/
```

Example: `user1-192.168.1.100.zip`

### Add ATAK Client

1. Create user certificate (see above)
2. Create user in web UI: https://<server>:8443
   - Users → Add User
   - Username must match certificate name
   - Assign to a group
3. Copy `.zip` file to Android/iOS device
4. In ATAK/iTAK:
   - Settings → Import → Local SD
   - Select the `.zip` file
   - ATAK will configure server connection automatically

## Automatic Startup on Boot (Optional)

To start TAK Server automatically when the system boots:

```bash
sudo nano /etc/systemd/system/tak-server.service
```

Add this content:

```ini
[Unit]
Description=TAK Server
Requires=docker.service
After=docker.service network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/opt/tak-server/tak-server
ExecStart=/run/current-system/sw/bin/docker-compose up -d
ExecStop=/run/current-system/sw/bin/docker-compose down
User=noahbalboa66

[Install]
WantedBy=multi-user.target
```

Enable and start:

```bash
sudo systemctl daemon-reload
sudo systemctl enable tak-server.service
sudo systemctl start tak-server.service
```

Check status:

```bash
sudo systemctl status tak-server.service
```

## Network Ports

The following ports are used by TAK Server:

| Port | Service | Description |
|------|---------|-------------|
| 5432 | PostgreSQL | Database |
| 8089 | TAK API | REST API |
| 8443 | Web UI | HTTPS admin interface |
| 8444 | TAK Server | Client connections |
| 8446 | Federation | Server-to-server federation |
| 9000 | Streaming | Video/data streaming |
| 9001 | Streaming | Video/data streaming |

**Firewall**: If `openFirewall = true` in your NixOS config, these ports are automatically opened.

To check if ports are open:

```bash
sudo netstat -tulpn | grep -E ':(5432|8089|8443|8444|8446|9000|9001)'
```

## Troubleshooting

### Port Conflicts

If setup fails due to port conflicts:

```bash
# Check what's using the ports
sudo netstat -tulpn | grep -E ':(5432|8089|8443|8444|8446|9000|9001)'

# Stop conflicting services
sudo systemctl stop <service-name>
```

### Docker Not Running

```bash
# Check Docker status
sudo systemctl status docker

# Start Docker
sudo systemctl start docker

# Check if you're in docker group
groups
# Should show "docker"

# If not, log out and back in after NixOS rebuild
```

### Reset TAK Server

To completely reset and start over:

```bash
cd /opt/tak-server/tak-server

# Run cleanup script
./scripts/cleanup.sh

# Re-run setup
./scripts/setup.sh
```

### Certificate Issues

If browser can't authenticate:

1. Verify certificate is imported correctly
2. Check certificate name matches
3. Try clearing browser cache
4. Ensure you're using HTTPS (not HTTP)

### Container Won't Start

```bash
# Check logs for errors
docker-compose logs

# Check disk space
df -h

# Check memory
free -h

# Restart Docker
sudo systemctl restart docker
docker-compose up -d
```

## Federation (Advanced)

To federate with other TAK servers:

1. Get the other server's CA certificate (`ca.pem`)
2. Import it:

```bash
cd /opt/tak-server/tak-server
keytool -importcert \
  -file other-server-ca.pem \
  -keystore tak/certs/files/fed-truststore.jks \
  -alias "other-tak-server"
```

## Security Best Practices

1. **Change default passwords**
   - Admin password
   - Certificate password (default: `atakatak`)

2. **Use strong certificates**
   - Generate unique certificates for each user
   - Protect `.p12` files

3. **Firewall management**
   - Only expose ports you need
   - Use VPN for remote access (recommended)

4. **Regular updates**
   - Check tak.gov for new releases
   - Keep NixOS updated: `sudo nixos-rebuild switch`

5. **Backup**
   - Database: `/opt/tak-server/tak-server/tak/db-data/`
   - Certificates: `/opt/tak-server/tak-server/tak/certs/`
   - Configuration: `/opt/tak-server/tak-server/tak/`

6. **VPN recommended**
   - Consider running behind OpenVPN or WireGuard
   - Reduces exposure of TAK ports to internet

## NixOS Configuration Reference

Your TAK Server module configuration in `hosts/server-tenoko/configuration.nix`:

```nix
services.tak-server = {
  # Enable TAK Server tools and Docker
  enable = true;
  
  # Working directory for TAK Server files
  workDir = "/opt/tak-server";
  
  # Automatically open firewall ports
  # Set to false to manage ports manually
  openFirewall = true;
};
```

**What this does:**
- Installs Docker, docker-compose, git, unzip, nettools, curl, wget
- Enables Docker daemon
- Adds your user to `docker` group
- Creates `/opt/tak-server` directory (owned by you)
- Opens firewall ports (if enabled)

**What it doesn't do:**
- Download TAK Server (you do this manually)
- Run setup script (you do this manually)
- Start services automatically (optional, see above)

## Useful Resources

- **TAK.gov**: https://tak.gov/products/tak-server
- **Cloud-RF Repository**: https://github.com/Cloud-RF/tak-server
- **TAK Documentation**: https://github.com/TAK-Product-Center/Server
- **ATAK (Android)**: https://play.google.com/store/apps/details?id=com.atakmap.app.civ
- **iTAK (iOS)**: https://apps.apple.com/app/itak/id1561656396
- **WinTAK**: https://tak.gov/products/wintak-civ

## Quick Reference Commands

```bash
# Navigate to TAK directory
cd /opt/tak-server/tak-server

# Start TAK Server
docker-compose up -d

# Stop TAK Server
docker-compose down

# View logs
docker-compose logs -f

# Check status
docker-compose ps

# Create user certificate
./scripts/setup.sh

# Reset everything
./scripts/cleanup.sh && ./scripts/setup.sh
```

## Getting Help

- **Setup issues**: Check the Cloud-RF repository issues
- **TAK Server issues**: TAK.gov support
- **NixOS issues**: Your 4Nix repository or NixOS discourse
- **Docker issues**: Check Docker logs and status

---

**Remember**: This is a manual setup approach. NixOS provides the tools and environment, but you control the TAK Server installation and management. This gives you full flexibility to follow official documentation and customize as needed.
