#!/usr/bin/fish
# FastWrt backup script - Implementation using fish shell
# Fish shell is the default shell in FastWrt and should be used for all scripts

# Source common color definitions
source "$PROFILE_DIR/colors.fish"

# Ensure the script runs from its own directory
cd $BASE_DIR
echo "$blue""Current working directory: ""$reset"(pwd)

# Log the purpose of the script
echo "$purple""Starting backup script to create backups of critical configuration files...""$reset"

# Set up backup directory and timestamp
set BACKUP_DIR "/etc/config/backups"
mkdir -p $BACKUP_DIR
set TIMESTAMP (date +"%Y%m%d-%H%M%S")

# Define backup function with fish's improved syntax
function backup_file
    set file $argv[1]
    set filename (basename $file)
    set backup_path "$BACKUP_DIR/$filename.bak.$TIMESTAMP"
    
    echo "$blue""Backing up $file to $backup_path""$reset"
    
    if not cp $file $backup_path
        echo "$red""ERROR: Failed to backup $file""$reset" >&2
        exit 1
    end
    
    echo "$green""✓ Successfully backed up $file""$reset"
end

# Execute backups with better progress information
echo "$blue""Starting backup process at ""$reset"(date)
echo "$yellow""━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━""$reset"

backup_file "/etc/config/network"
backup_file "/etc/config/firewall"
backup_file "/etc/config/dropbear"
backup_file "/etc/config/system"
backup_file "/etc/config/dhcp"

echo "$yellow""━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━""$reset"
echo "$green""Backup completed at ""$reset"(date)
echo "$green""Backups stored in $BACKUP_DIR""$reset"