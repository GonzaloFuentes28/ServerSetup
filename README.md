# Server Initial Setup and Hardening Script

A comprehensive bash script for setting up and hardening fresh Ubuntu/Debian servers with security best practices, Docker installation, and monitoring tools.

## Table of Contents

- [Features](#features)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Usage](#usage)
- [What the Script Does](#what-the-script-does)
- [Security Considerations](#security-considerations)
- [Post-Installation Steps](#post-installation-steps)
- [Troubleshooting](#troubleshooting)
- [Important Warnings](#important-warnings)

## Features

### Security Hardening
- **SSH Hardening**: Disables root login, password authentication, and enforces key-based authentication only
- **User Access Control**: Creates a new sudo user with restricted SSH access
- **Firewall Configuration**: Sets up UFW (Uncomplicated Firewall) with customizable port access
- **Intrusion Prevention**: Installs and configures fail2ban to block brute-force attacks
- **Automatic Updates**: Configures unattended-upgrades for automatic security patches

### System Setup
- **System Updates**: Updates all packages to latest versions
- **Docker Installation**: Optional Docker Engine with docker-compose plugin
- **Monitoring Tools**: Installs htop, iotop, and nethogs for system monitoring
- **Input Validation**: Validates usernames and port numbers to prevent configuration errors

### Safety Features
- **Configuration Backup**: Backs up SSH config before making changes
- **Automatic Rollback**: Restores SSH config if validation fails
- **Lockout Prevention**: Forces SSH testing before applying changes
- **Safe Exit Options**: Allows exiting without restarting SSH service

## Prerequisites

- Fresh Ubuntu 20.04+ or Debian 10+ server
- Root access to the server
- SSH key pair generated on your local machine
- Active internet connection on the server

## Installation

1. **Upload the script to your server:**
   ```bash
   scp setup.sh root@your_server_ip:/root/
   ```

2. **Connect to your server:**
   ```bash
   ssh root@your_server_ip
   ```

3. **Make the script executable:**
   ```bash
   chmod +x setup.sh
   ```

## Usage

Run the script as root:

```bash
sudo bash setup.sh
```

### Interactive Prompts

The script will ask you for:

1. **Username**: Enter a username for the new sudo user (lowercase letters, numbers, underscore, hyphen only)
2. **User Password**: Set a password for the new user (used for sudo operations)
3. **Copy SSH Keys**: Whether to copy root's SSH keys to the new user (recommended: yes)
4. **Additional Ports**: Whether to open additional firewall ports (e.g., 80, 443)
5. **Port Numbers**: Comma-separated list of ports to open (if applicable)
6. **Docker Installation**: Whether to install Docker and docker-compose
7. **SSH Testing Confirmation**: Confirm that you've tested SSH with the new user
8. **SSH Restart**: Whether to restart SSH service immediately

## What the Script Does

### 1. System Package Updates
- Updates package lists
- Upgrades all installed packages to latest versions

### 2. User Management
- Creates a new user with sudo privileges
- Validates username format (no special characters, proper Linux username format)
- Optionally copies SSH authorized_keys from root

### 3. SSH Key Setup
- Copies root's authorized_keys to new user
- Sets proper permissions (700 for .ssh, 600 for authorized_keys)
- Sets correct ownership

### 4. fail2ban Installation
- Installs fail2ban for intrusion prevention
- Configures SSH jail with:
  - Ban time: 24 hours (86400 seconds)
  - Max retries: 3 attempts
  - Find time: 10 minutes (600 seconds)
- Enables and starts the service

### 5. UFW Firewall Setup
- Installs UFW firewall
- Sets default policies (deny incoming, allow outgoing)
- Automatically detects and opens SSH port
- Allows custom ports as specified by user
- Validates all port numbers (1-65535)

### 6. SSH Hardening
- **Disables root login** (`PermitRootLogin no`)
- **Disables password authentication** (`PasswordAuthentication no`)
- **Enables public key authentication** (`PubkeyAuthentication yes`)
- **Disables challenge-response authentication**
- **Disables X11 forwarding** (reduces attack surface)
- **Restricts access to specific user** (AllowUsers directive)
- Creates backup at `/etc/ssh/sshd_config.backup`

### 7. Automatic Security Updates
- Installs unattended-upgrades package
- Configures automatic security updates
- Enables automatic kernel package cleanup
- Disables automatic reboots (manual reboot control)

### 8. System Monitoring Tools
- **htop**: Interactive process viewer
- **iotop**: Disk I/O monitoring
- **nethogs**: Network bandwidth monitoring per process

### 9. Docker Installation (Optional)
- Adds Docker's official GPG key and repository
- Installs Docker Engine, CLI, and containerd
- Installs docker-buildx-plugin and docker-compose-plugin
- Adds new user to docker group (enables non-root Docker usage)
- Enables Docker service to start on boot
- Verifies installation

### 10. SSH Configuration Validation
- Tests SSH configuration syntax before applying
- Automatically restores backup if configuration is invalid
- Prevents breaking SSH access due to syntax errors

### 11. Final Safety Check
- Forces user confirmation of successful SSH test
- Provides recovery instructions
- Offers option to restart SSH or exit safely

## Security Considerations

### Critical Security Changes

1. **Root login is disabled**: You cannot SSH as root after running this script
2. **Password authentication is disabled**: Only SSH key authentication works
3. **SSH access is restricted**: Only the created user can SSH in
4. **Firewall is active**: Only specified ports are accessible

### Before Running

- Ensure you have SSH key pair generated
- Verify you can access the server via SSH
- Have console access available (VPS control panel) in case of lockout
- Back up any important data

### After Running

- Test SSH access BEFORE restarting SSH service
- Keep the root session open until verified
- Save the SSH config backup location: `/etc/ssh/sshd_config.backup`

## Post-Installation Steps

### 1. Verify SSH Access

Open a **NEW** terminal (keep the current one open) and test:

```bash
ssh your_username@your_server_ip
```

Verify you can:
- Log in with your SSH key
- Run commands with sudo: `sudo whoami`

### 2. Test Docker (if installed)

After logging in with the new user:

```bash
# Verify Docker is running
docker --version
docker compose version

# Test Docker (may require logout/login first)
docker run hello-world

# If you get permission denied, logout and login again:
exit
ssh your_username@your_server_ip
docker run hello-world
```

### 3. Configure Additional Services

Depending on your needs, you may want to:

- **Install Caddy web server** (with automatic HTTPS):
  ```bash
  # Install Caddy
  sudo apt install -y debian-keyring debian-archive-keyring apt-transport-https
  curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
  curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list
  sudo apt update
  sudo apt install caddy

  # Allow HTTP and HTTPS through firewall
  sudo ufw allow 80/tcp
  sudo ufw allow 443/tcp

  # Caddy automatically handles SSL certificates via Let's Encrypt
  # Edit the Caddyfile to configure your site
  sudo nano /etc/caddy/Caddyfile

  # Example Caddyfile configuration:
  # yourdomain.com {
  #     reverse_proxy localhost:3000
  # }

  # Restart Caddy to apply changes
  sudo systemctl reload caddy
  ```

- **Configure database**:
  ```bash
  # PostgreSQL
  sudo apt install postgresql postgresql-contrib

  # MySQL
  sudo apt install mysql-server
  ```

### 4. Set Up SSH Key on Local Machine (if not done)

On your **local machine**:

```bash
# Generate SSH key pair (if you don't have one)
ssh-keygen -t ed25519 -C "your_email@example.com"

# Copy public key to server
ssh-copy-id your_username@your_server_ip
```

### 5. Configure Hostname

```bash
sudo hostnamectl set-hostname your-hostname
sudo nano /etc/hosts  # Add: 127.0.1.1 your-hostname
```

### 6. Set Up Timezone

```bash
sudo timedatectl set-timezone America/New_York  # Use your timezone
timedatectl  # Verify
```

### 7. Configure Swap (if needed)

```bash
# Check current swap
sudo swapon --show

# Create 2GB swap file
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile

# Make permanent
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
```

### 8. Monitor System

```bash
# Check fail2ban status
sudo fail2ban-client status sshd

# Check firewall status
sudo ufw status verbose

# Monitor system resources
htop

# Check disk I/O
sudo iotop

# Monitor network usage
sudo nethogs
```

### 9. Regular Maintenance

Set up regular maintenance tasks:

```bash
# Check for updates weekly
sudo apt update && sudo apt list --upgradable

# Review logs periodically
sudo journalctl -xe
sudo tail -f /var/log/auth.log

# Check fail2ban bans
sudo fail2ban-client status sshd

# Review disk usage
df -h
```

## Troubleshooting

### Locked Out of Server

If you get locked out after running the script:

1. **Use console access** (VPS control panel, IPMI, etc.)
2. **Login as root** via console
3. **Restore SSH config**:
   ```bash
   cp /etc/ssh/sshd_config.backup /etc/ssh/sshd_config
   systemctl restart sshd
   ```
4. **Fix the issue** (add SSH keys, check username, etc.)
5. **Re-run the script** or manually apply changes

### SSH Connection Refused

Check the SSH service status:
```bash
sudo systemctl status ssh
# or
sudo systemctl status sshd
```

Restart if needed:
```bash
sudo systemctl restart ssh
```

### Firewall Blocking SSH

If locked out due to firewall:
```bash
# Via console
sudo ufw allow 22/tcp
sudo ufw reload
```

### Docker Permission Denied

If you get "permission denied" when running Docker:
```bash
# Verify you're in the docker group
groups

# If not listed, logout and login again
exit
ssh your_username@your_server_ip

# Verify Docker works
docker run hello-world
```

### fail2ban Not Starting

Check the configuration:
```bash
sudo fail2ban-client -d
sudo systemctl status fail2ban
sudo journalctl -u fail2ban
```

Fix and restart:
```bash
sudo fail2ban-client reload
```

### Automatic Updates Not Working

Check configuration:
```bash
sudo systemctl status unattended-upgrades
sudo cat /etc/apt/apt.conf.d/50unattended-upgrades
```

Test manually:
```bash
sudo unattended-upgrade --dry-run --debug
```

## Important Warnings

### CRITICAL WARNINGS

1. **DO NOT close your root session until SSH is verified with the new user**
   - Keep the terminal open
   - Test in a NEW terminal window
   - Only close after successful login

2. **DO NOT run this script on a server with existing configurations**
   - This is designed for FRESH servers
   - May overwrite existing SSH, firewall, or security settings
   - Back up existing configs before running

3. **DO NOT restart SSH without testing first**
   - The script forces testing before restart
   - Always verify the new user can login
   - Have console access ready as backup

4. **DO NOT forget your user password**
   - Required for sudo operations
   - No password reset available without console access

### Recovery Information

**SSH Config Backup Location:**
```
/etc/ssh/sshd_config.backup
```

**Restore Command:**
```bash
sudo cp /etc/ssh/sshd_config.backup /etc/ssh/sshd_config
sudo systemctl restart ssh
```

**Emergency Access:**
- Use VPS provider's console/VNC access
- Login as root via console
- Restore configurations as needed

## Script Validation

The script includes multiple safety checks:

- ✓ Username validation (proper format)
- ✓ Port number validation (1-65535)
- ✓ SSH configuration syntax testing
- ✓ Automatic config rollback on errors
- ✓ Variable quoting to prevent injection
- ✓ Exit on error (`set -e`)
- ✓ Confirmation prompts for destructive actions

## Compatibility

**Tested on:**
- Ubuntu 20.04 LTS
- Ubuntu 22.04 LTS
- Debian 11 (Bullseye)
- Debian 12 (Bookworm)

**Requirements:**
- systemd-based system
- apt package manager
- bash shell

## License

This script is provided as-is for educational and practical use. Modify as needed for your environment.

## Support

For issues, questions, or contributions:
- Review the Troubleshooting section
- Check system logs: `sudo journalctl -xe`
- Test in a VM or sandbox environment first

---

**Last Updated:** 2024
**Version:** 1.0

**Remember:** Security is an ongoing process. Keep your system updated and monitor logs regularly.
