#!/bin/sh

set -e  # Exit on any error

# Log the purpose of the script
echo "Starting commit script to finalize and apply all changes..."

### --- Commit & Restart ---
echo "Setup completed. Backups stored in $BACKUP_DIR/"
echo "Press ENTER to commit changes and restart services (may disconnect SSH)."
read -r dummy  # Wait for user confirmation

uci commit

# Restart services (order matters)
/etc/init.d/firewall reload
/etc/init.d/dnsmasq restart
/etc/init.d/dropbear restart
/etc/init.d/network restart

echo "Services restarted. You may need to reconnect via SSH if IP/port changed."