#!/bin/sh
set -e  # Exit on any error
# Ensure the script runs from its own directory
cd "$BASE_DIR"
echo "Current working directory: $(pwd)"

# Log the purpose of the script
echo "Starting backup script to create backups of critical configuration files..."

BACKUP_DIR="/etc/config/backups"
mkdir -p "$BACKUP_DIR"
TIMESTAMP=$(date +"%Y%m%d-%H%M%S")

backup_file() {
  local file="$1"
  cp "$file" "$BACKUP_DIR/$(basename "$file").bak.$TIMESTAMP" || {
    echo "ERROR: Failed to backup $file" >&2
    exit 1
  }
}

backup_file "/etc/config/network"
backup_file "/etc/config/firewall"
backup_file "/etc/config/dropbear"
backup_file "/etc/config/system"
backup_file "/etc/config/dhcp"