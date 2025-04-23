#!/usr/bin/fish
# FastWrt post-installation tasks - Run after system is fully configured
# This script should be run manually after configuration is complete

# Set colors for better readability
set green (echo -e "\033[0;32m")
set yellow (echo -e "\033[0;33m")
set red (echo -e "\033[0;31m")
set blue (echo -e "\033[0;34m")
set purple (echo -e "\033[0;35m")
set reset (echo -e "\033[0m")

echo "$purple""FastWrt Post-Installation Tasks""$reset"

# Create backup of final configurations
echo "$blue""Creating backup of final configurations...""$reset"
set BACKUP_DIR "/etc/config/backups"
mkdir -p $BACKUP_DIR
set TIMESTAMP (date +"%Y%m%d-%H%M%S")

for config in network firewall dropbear system dhcp wireless
    if test -f "/etc/config/$config"
        set backup_path "$BACKUP_DIR/$config.installed.$TIMESTAMP"
        cp "/etc/config/$config" "$backup_path"
        echo "$green""Backed up $config to $backup_path""$reset"
    end
end

# Create post-install completion marker
touch "/etc/fastWrt_install_completed"

# Create reminder banner
echo "$blue""Creating post-installation banner...""$reset"
cat << 'EOF' > /etc/banner.post-install
=======================================================
FastWrt installation complete!

SECURITY NOTICE:
- SSH is accessible ONLY from internal networks and WireGuard
- For remote access, connect to WireGuard VPN first

System Information:
- Main IP: $(uci -q get network.core.ipaddr || echo "Not configured")
- Hostname: $(uci -q get system.@system[0].hostname || echo "FastWrt")
=======================================================
EOF

echo "$green""Created post-installation banner""$reset"

# Display system information
echo "$yellow""System Information:""$reset"
echo "Hostname: "(uci -q get system.@system[0].hostname || echo "FastWrt")
echo "Core IP: "(uci -q get network.core.ipaddr || echo "Not configured")
echo "WireGuard IP: "(uci -q get network.wireguard.ipaddr || echo "Not configured")

echo "$green""Post-installation tasks completed successfully.""$reset"
