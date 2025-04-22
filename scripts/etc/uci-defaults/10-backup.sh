#!/usr/bin/fish
# FastWrt backup script - Pure fish implementation

# Ensure the script runs from its own directory
cd $BASE_DIR
echo "Current working directory: "(pwd)

# Log the purpose of the script
echo "Starting backup script to create backups of critical configuration files..."

# Set up backup directory and timestamp
set BACKUP_DIR "/etc/config/backups"
mkdir -p $BACKUP_DIR
set TIMESTAMP (date +"%Y%m%d-%H%M%S")

# Define backup function with fish's improved syntax
function backup_file
    set file $argv[1]
    set filename (basename $file)
    set backup_path "$BACKUP_DIR/$filename.bak.$TIMESTAMP"
    
    echo "Backing up $file to $backup_path"
    
    if not cp $file $backup_path
        echo "ERROR: Failed to backup $file" >&2
        exit 1
    end
    
    echo "✓ Successfully backed up $file"
end

# Execute backups with better progress information
echo "Starting backup process at "(date)
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

backup_file "/etc/config/network"
backup_file "/etc/config/firewall"
backup_file "/etc/config/dropbear"
backup_file "/etc/config/system"
backup_file "/etc/config/dhcp"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Backup completed at "(date)
echo "Backups stored in $BACKUP_DIR"