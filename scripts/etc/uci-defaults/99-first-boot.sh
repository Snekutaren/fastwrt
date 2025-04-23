#!/usr/bin/fish
# FastWrt first-boot configuration - Implementation using fish shell
# Fish shell is the default shell in FastWrt and should be used for all scripts

# Set colors for better readability
set green (echo -e "\033[0;32m")
set yellow (echo -e "\033[0;33m")
set red (echo -e "\033[0;31m")
set blue (echo -e "\033[0;34m")
set purple (echo -e "\033[0;35m")
set reset (echo -e "\033[0m")

set LOGFILE "/tmp/first-boot.log"
echo "$purple""Starting FastWrt first boot configuration at ""$reset"(date) > $LOGFILE

# Make sure first-boot only runs once by creating a marker file
set FIRST_BOOT_MARKER "/etc/fastWrt_first_boot_completed"

# Check for --force flag to enable rerunning if needed
set force_run false
if test (count $argv) -gt 0; and test "$argv[1]" = "--force"
    set force_run true
    echo "$yellow""Force flag detected, running regardless of marker file""$reset"
    rm -f "$FIRST_BOOT_MARKER" 2>/dev/null
end

# Skip if already run (unless forced)
if test -f "$FIRST_BOOT_MARKER"; and test "$force_run" = "false"
    echo "$yellow""First boot script has already run. To force re-execution, run:""$reset"
    echo "$blue""  /etc/uci-defaults/99-first-boot.sh --force""$reset"
    exit 0
else
    echo "$purple""Running first-boot configuration...""$reset"
end

# Create required directories
mkdir -p /etc/dropbear
chmod 700 /etc/dropbear

# FIRST-BOOT SPECIFIC RESPONSIBILITIES:
# 1. SSH keys and authentication
# 2. Initial backup creation
# 3. Post-configuration tasks that shouldn't run again

function add_default_ssh_key
    echo "$blue""Setting up initial SSH key for secure access...""$reset" >> $LOGFILE

    touch /etc/dropbear/authorized_keys
    chmod 600 /etc/dropbear/authorized_keys

    if test -f "/etc/FastWrt/ssh_keys/id_ed25519.pub"
        cat "/etc/FastWrt/ssh_keys/id_ed25519.pub" >> /etc/dropbear/authorized_keys
        echo "$green""SSH key added successfully from installed id_ed25519.pub""$reset" >> $LOGFILE
    else
        echo "$yellow""No SSH key found in standard location, using embedded key...""$reset" >> $LOGFILE
        begin
            echo "ssh-rsa AAAA...YOUR_SSH_PUBLIC_KEY_HERE...== user@example.com"
        end >> /etc/dropbear/authorized_keys
    end

    chmod 600 /etc/dropbear/authorized_keys
end

function configure_initial_ssh
    echo "$blue""Configuring initial secure SSH settings...""$reset" >> $LOGFILE

    # Avoid redundancy with 70-dropbear.sh - only set values not already handled
    # Only set Interface and Port if not already configured by 70-dropbear.sh
    if not uci -q get dropbear.@dropbear[0].Interface > /dev/null
        uci set dropbear.@dropbear[0].Interface='core'
    end
    
    if not uci -q get dropbear.@dropbear[0].Port > /dev/null
        uci set dropbear.@dropbear[0].Port='6622'
    end

    # Only handle SSH key-based authentication here, not in 70-dropbear.sh
    if grep -q "ssh-" "/etc/dropbear/authorized_keys"
        echo "$green""Valid SSH keys found, disabling password authentication""$reset" >> $LOGFILE
        uci set dropbear.@dropbear[0].PasswordAuth='off'
        uci set dropbear.@dropbear[0].RootPasswordAuth='off'
    else
        echo "$yellow""No valid SSH keys found, keeping password authentication enabled""$reset" >> $LOGFILE
        uci set dropbear.@dropbear[0].PasswordAuth='on'
        uci set dropbear.@dropbear[0].RootPasswordAuth='on'
    end
    
    # Commit only if changes were made
    if uci changes dropbear | grep -q '.'
        echo "$green""Committing dropbear changes""$reset" >> $LOGFILE
        uci commit dropbear
    else
        echo "$yellow""No dropbear changes to commit""$reset" >> $LOGFILE
    end
end

function backup_initial_configs
    echo "$blue""Creating initial configuration backups...""$reset" >> $LOGFILE
    set BACKUP_DIR "/etc/config/backups"
    mkdir -p $BACKUP_DIR

    for config in network firewall dropbear system dhcp
        if test -f "/etc/config/$config"
            cp "/etc/config/$config" "$BACKUP_DIR/$config.initial"
        else
            echo "$yellow""Warning: Config file /etc/config/$config not found, skipping backup""$reset" >> $LOGFILE
        end
    end

    echo "$green""Initial configuration backups created""$reset" >> $LOGFILE
end

# Execute first-boot specific functions in proper order
echo "$purple""Executing first boot tasks...""$reset" >> $LOGFILE
add_default_ssh_key
configure_initial_ssh
backup_initial_configs

# Write reminder banner - ensure it's idempotent
if not test -f "/etc/banner.post-sysupgrade"; or test "$force_run" = "true"
    begin
        echo "======================================================="
        echo "FastWrt initial setup complete!"
        echo ""
        echo "SECURITY NOTICE:"
        echo "- SSH is accessible ONLY from internal networks and WireGuard"
        echo "- For remote access, connect to WireGuard VPN first"
        echo ""
        echo "To run first-boot configuration again:"
        echo "  /etc/uci-defaults/99-first-boot.sh --force"
        echo "======================================================="
    end > /etc/banner.post-sysupgrade
end

# Create the marker file to prevent re-execution
touch "$FIRST_BOOT_MARKER"
echo "$green""Created marker file to prevent re-execution""$reset" >> $LOGFILE

echo "$green""First boot configuration completed at ""$reset"(date) >> $LOGFILE
echo "$green""FastWrt first boot configuration completed successfully. See $LOGFILE for details.""$reset" > /dev/console

exit 0
