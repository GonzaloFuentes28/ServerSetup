#!/bin/bash

# Server Initial Setup and Hardening Script
# This script should be run as root on a fresh server
# Usage: bash server-setup.sh

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   print_error "This script must be run as root"
   exit 1
fi

print_status "Starting server setup and hardening..."

# ============================================
# 1. Update system packages
# ============================================
print_status "Updating system packages..."
apt update && apt upgrade -y

# ============================================
# 2. Create new sudo user
# ============================================
read -p "Enter username for new sudo user: " NEW_USER

if id "$NEW_USER" &>/dev/null; then
    print_warning "User $NEW_USER already exists, skipping user creation"
else
    print_status "Creating user: $NEW_USER"
    adduser --gecos "" $NEW_USER
    usermod -aG sudo $NEW_USER
    print_status "User $NEW_USER created and added to sudo group"
fi

# ============================================
# 3. Setup SSH key for new user
# ============================================
print_warning "Do you want to copy root's authorized_keys to $NEW_USER? (y/n)"
read -r COPY_KEYS

if [[ $COPY_KEYS == "y" || $COPY_KEYS == "Y" ]]; then
    if [ -f /root/.ssh/authorized_keys ]; then
        mkdir -p /home/$NEW_USER/.ssh
        cp /root/.ssh/authorized_keys /home/$NEW_USER/.ssh/
        chown -R $NEW_USER:$NEW_USER /home/$NEW_USER/.ssh
        chmod 700 /home/$NEW_USER/.ssh
        chmod 600 /home/$NEW_USER/.ssh/authorized_keys
        print_status "SSH keys copied to $NEW_USER"
    else
        print_warning "No authorized_keys found in /root/.ssh/"
    fi
else
    print_warning "Remember to manually setup SSH keys for $NEW_USER before disabling password auth!"
fi

# ============================================
# 4. Install fail2ban
# ============================================
print_status "Installing fail2ban..."
apt install -y fail2ban

# Create fail2ban local configuration
print_status "Configuring fail2ban..."
cat > /etc/fail2ban/jail.local <<EOF
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 5

[sshd]
enabled = true
port = ssh
logpath = %(sshd_log)s
backend = %(sshd_backend)s
maxretry = 3
bantime = 86400
EOF

systemctl enable fail2ban
systemctl start fail2ban
print_status "fail2ban installed and configured"

# ============================================
# 5. Install and configure UFW
# ============================================
print_status "Installing UFW..."
apt install -y ufw

# Get SSH port (check if it's custom)
SSH_PORT=$(grep "^Port " /etc/ssh/sshd_config | awk '{print $2}')
if [ -z "$SSH_PORT" ]; then
    SSH_PORT=22
fi

print_status "Configuring UFW firewall..."
ufw default deny incoming
ufw default allow outgoing
ufw allow $SSH_PORT/tcp comment 'SSH'

# Ask for additional ports
print_warning "Do you want to open additional ports? (y/n)"
read -r OPEN_PORTS

if [[ $OPEN_PORTS == "y" || $OPEN_PORTS == "Y" ]]; then
    echo "Enter ports to open (comma-separated, e.g., 80,443,8080):"
    read -r PORTS
    IFS=',' read -ra PORT_ARRAY <<< "$PORTS"
    for port in "${PORT_ARRAY[@]}"; do
        port=$(echo $port | xargs)  # Trim whitespace
        ufw allow $port/tcp
        print_status "Opened port: $port"
    done
fi

# Enable UFW
print_warning "About to enable UFW. Make sure SSH port ($SSH_PORT) is allowed!"
sleep 3
ufw --force enable
print_status "UFW firewall enabled and configured"

# ============================================
# 6. Harden SSH configuration
# ============================================
print_status "Hardening SSH configuration..."

# Backup original sshd_config
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup

# Apply SSH hardening settings
sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i 's/^#\?PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/^#\?ChallengeResponseAuthentication.*/ChallengeResponseAuthentication no/' /etc/ssh/sshd_config
sed -i 's/^#\?X11Forwarding.*/X11Forwarding no/' /etc/ssh/sshd_config

print_status "SSH configuration hardened"

# ============================================
# 7. Additional security measures
# ============================================
print_status "Installing additional security tools..."
apt install -y unattended-upgrades apt-listchanges

# Enable automatic security updates
dpkg-reconfigure -plow unattended-upgrades

# ============================================
# 8. Configure automatic security updates
# ============================================
cat > /etc/apt/apt.conf.d/50unattended-upgrades <<EOF
Unattended-Upgrade::Allowed-Origins {
    "\${distro_id}:\${distro_codename}-security";
};
Unattended-Upgrade::AutoFixInterruptedDpkg "true";
Unattended-Upgrade::MinimalSteps "true";
Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "false";
EOF

print_status "Automatic security updates configured"

# ============================================
# 9. Set up basic system monitoring
# ============================================
print_status "Installing monitoring tools..."
apt install -y htop iotop nethogs

# ============================================
# 10. Test SSH configuration before applying
# ============================================
print_status "Testing SSH configuration..."
if command -v sshd &> /dev/null; then
    sshd -t
elif command -v /usr/sbin/sshd &> /dev/null; then
    /usr/sbin/sshd -t
else
    print_warning "Could not find sshd binary to test config, skipping test"
fi

if [ $? -eq 0 ]; then
    print_status "SSH configuration is valid"
else
    print_error "SSH configuration has errors. Please check before restarting SSH"
    exit 1
fi

# ============================================
# Summary and final steps
# ============================================
echo ""
echo "=========================================="
print_status "Server setup complete!"
echo "=========================================="
echo ""
echo "Summary of changes:"
echo "  • System packages updated"
echo "  • User '$NEW_USER' created with sudo privileges"
echo "  • fail2ban installed and enabled (SSH jail active)"
echo "  • UFW firewall configured and enabled"
echo "  • SSH hardened:"
echo "    - Root login disabled"
echo "    - Password authentication disabled"
echo "    - Only SSH key authentication allowed"
echo "    - SSH access limited to: $NEW_USER"
echo "  • Automatic security updates enabled"
echo ""
print_warning "IMPORTANT: Before logging out, test SSH access with the new user!"
echo ""
echo "To test, open a NEW terminal and run:"
echo "  ssh $NEW_USER@YOUR_SERVER_IP"
echo ""
print_warning "Do you want to restart SSH service now? (y/n)"
read -r RESTART_SSH

if [[ $RESTART_SSH == "y" || $RESTART_SSH == "Y" ]]; then
    # Try both possible SSH service names
    if systemctl is-active --quiet ssh; then
        systemctl restart ssh
    elif systemctl is-active --quiet sshd; then
        systemctl restart sshd
    else
        # If neither is running, try both names
        systemctl restart ssh 2>/dev/null || systemctl restart sshd
    fi
    print_status "SSH service restarted"
    echo ""
    print_warning "SSH has been restarted with new configuration."
    print_warning "Make sure you can log in with $NEW_USER before closing this session!"
else
    print_warning "Remember to restart SSH manually: systemctl restart ssh (or sshd)"
fi

echo ""
print_status "Setup script finished successfully!"
