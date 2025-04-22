#!/usr/bin/fish
# FastWrt final commit script - Pure fish implementation

# Ensure the script runs from its own directory
cd $BASE_DIR
echo "Current working directory: "(pwd)

# Log the purpose of the script
echo "Starting commit script to finalize and apply all changes..."

### --- Commit & Restart ---
echo "Setup completed. Backups stored in $BACKUP_DIR/"

# Handle dry run mode
if test "$DRY_RUN" = "true"
    echo "╔════════════════════════════════════════╗"
    echo "║  DRY RUN MODE - SHOWING PENDING CHANGES  ║"
    echo "╚════════════════════════════════════════╝"
    
    # Show all pending changes across all UCI configurations
    echo "Pending changes that would be applied:"
    uci changes
    
    # Ask for confirmation before reverting
    echo "Press ENTER to revert all changes (dry run complete)."
    read -l dummy
    
    # Revert all pending changes
    echo "Reverting all changes..."
    uci revert
    
    echo "Dry run complete. No changes have been committed."
    exit 0
else
    echo "Press ENTER to commit changes and restart services (may disconnect SSH)."
    read -l dummy  # Wait for user confirmation
    
    uci commit
    
    # Restart services (order matters)
    /etc/init.d/firewall reload
    /etc/init.d/dnsmasq reload
    /etc/init.d/dropbear restart
    /etc/init.d/network restart
    
    echo "Services restarted. You may need to reconnect via SSH if IP/port changed."
end