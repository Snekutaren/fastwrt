#!/bin/sh
# FastWrt first boot script - Runs on initial boot after firmware installation
# This script will be placed in /etc/uci-defaults/ to execute on first boot

# Create log file
LOGFILE="/tmp/first-boot.log"
echo "Starting FastWrt first boot configuration at $(date)" > $LOGFILE

# Create required directories
mkdir -p /etc/dropbear
chmod 700 /etc/dropbear

# Function to add default SSH key for initial access
add_default_ssh_key() {
    echo "Setting up initial SSH key for secure access..." >> $LOGFILE
    
    # Create authorized_keys file if it doesn't exist
    touch /etc/dropbear/authorized_keys
    chmod 600 /etc/dropbear/authorized_keys
    
    # Check if we have an SSH key in the default location
    if [ -f "/etc/FastWrt/ssh_keys/id_ed25519.pub" ]; then
        cat "/etc/FastWrt/ssh_keys/id_ed25519.pub" >> /etc/dropbear/authorized_keys
        echo "SSH key added successfully from installed id_ed25519.pub" >> $LOGFILE
    else
        # Embedded SSH public key - REPLACE THIS WITH YOUR ACTUAL PUBLIC KEY
        # Only used as fallback if no keys are found in the expected locations
        echo "No SSH key found in standard location, using embedded key..." >> $LOGFILE
        cat << 'EOF' >> /etc/dropbear/authorized_keys
ssh-rsa AAAA...YOUR_SSH_PUBLIC_KEY_HERE...== user@example.com
EOF
    fi
    
    # Set proper permissions
    chmod 600 /etc/dropbear/authorized_keys
}

# Set minimum secure SSH configuration
# More comprehensive security settings will be applied by secure_ssh.sh during setup
configure_initial_ssh() {
    echo "Configuring initial secure SSH settings..." >> $LOGFILE
    
    # Set dropbear to use port 6622 on core interface
    uci set dropbear.@dropbear[0].Interface='core'
    uci set dropbear.@dropbear[0].Port='6622'
    
    # Only disable password auth if we have a valid SSH key
    if grep -q "ssh-" "/etc/dropbear/authorized_keys" 2>/dev/null; then
        echo "Valid SSH keys found, disabling password authentication" >> $LOGFILE
        uci set dropbear.@dropbear[0].PasswordAuth='off'
        uci set dropbear.@dropbear[0].RootPasswordAuth='off'
    else
        echo "No valid SSH keys found, keeping password authentication enabled" >> $LOGFILE
        # Keep password auth enabled if no SSH keys are present
        uci set dropbear.@dropbear[0].PasswordAuth='on'
        uci set dropbear.@dropbear[0].RootPasswordAuth='on'
    fi
    
    # Add SSH firewall rules - only allow from internal networks, not WAN
    echo "Configuring SSH firewall access rules (internal only)..." >> $LOGFILE
    
    # Allow SSH access only from core network
    uci set firewall.ssh_access_core='rule'
    uci set firewall.ssh_access_core.name='SSH-from-core'
    uci set firewall.ssh_access_core.src='core'
    uci set firewall.ssh_access_core.proto='tcp'
    uci set firewall.ssh_access_core.dest_port='6622'
    uci set firewall.ssh_access_core.target='ACCEPT'
    
    # Allow SSH access from WireGuard VPN
    uci set firewall.ssh_access_wireguard='rule'
    uci set firewall.ssh_access_wireguard.name='SSH-from-wireguard'
    uci set firewall.ssh_access_wireguard.src='wireguard'
    uci set firewall.ssh_access_wireguard.proto='tcp'
    uci set firewall.ssh_access_wireguard.dest_port='6622'
    uci set firewall.ssh_access_wireguard.target='ACCEPT'
    
    # Explicitly block SSH access from WAN for clarity
    uci set firewall.ssh_block_wan='rule'
    uci set firewall.ssh_block_wan.name='SSH-block-wan'
    uci set firewall.ssh_block_wan.src='wan'
    uci set firewall.ssh_block_wan.proto='tcp'
    uci set firewall.ssh_block_wan.dest_port='6622'
    uci set firewall.ssh_block_wan.target='REJECT'
    uci set firewall.ssh_block_wan.enabled='1'
    
    # Commit changes directly since this is first boot
    uci commit dropbear
    uci commit firewall
    
    echo "SSH configured for internal and WireGuard access only (no WAN access)" >> $LOGFILE
}

# Create backup of default configurations
backup_initial_configs() {
    echo "Creating initial configuration backups..." >> $LOGFILE
    BACKUP_DIR="/etc/config/backups"
    mkdir -p $BACKUP_DIR
    
    for config in network firewall dropbear system dhcp; do
        cp /etc/config/$config $BACKUP_DIR/$config.initial
    done
    
    echo "Initial configuration backups created" >> $LOGFILE
}

# Execute functions
echo "Executing first boot tasks..." >> $LOGFILE
add_default_ssh_key
configure_initial_ssh
backup_initial_configs

# Create reminder to run full security setup
cat << 'EOF' > /etc/banner.post-sysupgrade
=======================================================
FastWrt initial setup complete!

SECURITY NOTICE:
- SSH is accessible ONLY from internal networks and WireGuard
- For remote access, connect to WireGuard VPN first

For full security hardening, run:
  cd /etc/FastWrt/Firmware && ./scripts/secure_ssh.sh
=======================================================
EOF

# Complete the setup
echo "First boot configuration completed at $(date)" >> $LOGFILE
echo "FastWrt first boot configuration completed successfully. See $LOGFILE for details." > /dev/console

# Return 0 to indicate successful execution
exit 0