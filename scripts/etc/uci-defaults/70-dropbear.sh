#!/usr/bin/fish
# FastWrt Dropbear (SSH) configuration - Implementation using fish shell
# Fish shell is the default shell in FastWrt and should be used for all scripts

# Set colors for better readability
set green (echo -e "\033[0;32m")
set yellow (echo -e "\033[0;33m")
set red (echo -e "\033[0;31m")
set blue (echo -e "\033[0;34m")
set purple (echo -e "\033[0;35m")
set reset (echo -e "\033[0m")

# Ensure the script runs from its own directory
cd $BASE_DIR
echo "$blue""Current working directory: ""$reset"(pwd)

# Log the purpose of the script
echo "$purple""Starting Dropbear configuration script to set up SSH access...""$reset"

### --- Dropbear (SSH) ---
# DROPBEAR SPECIFIC RESPONSIBILITIES:
# 1. Basic SSH configuration (port, interface)
# 2. SSH settings in UCI

echo "$blue""Setting Dropbear interface to 'core'...""$reset"
uci set dropbear.@dropbear[0].Interface='core'
echo "$blue""Setting Dropbear port to '6622'...""$reset"
uci set dropbear.@dropbear[0].Port='6622'

# Don't duplicate first-boot responsibilities:
# - Don't change PasswordAuth/RootPasswordAuth settings (done in first-boot)
# - Don't handle key management (done in first-boot)

# Try to add SSH keys but don't override first-boot configuration
echo "$blue""Checking for SSH keys to add...""$reset"
set ssh_keys_dir "$BASE_DIR/ssh_keys"

if test -d "$ssh_keys_dir"
    # Check for public keys in the ssh_keys directory
    for key_file in $ssh_keys_dir/*.pub
        if test -f "$key_file"
            echo "$green""Found key file: $key_file""$reset"
            # Only create directory if it doesn't exist (avoid overriding first-boot)
            mkdir -p /etc/dropbear
            chmod 700 /etc/dropbear
            
            # Create authorized_keys if it doesn't exist
            if not test -f "/etc/dropbear/authorized_keys"
                touch /etc/dropbear/authorized_keys
                chmod 600 /etc/dropbear/authorized_keys
            end
            
            # Add the key without duplication - check if it exists first
            set key_content (cat "$key_file")
            if not grep -qFx "$key_content" "/etc/dropbear/authorized_keys"
                echo "$blue""Adding key from $key_file to authorized_keys...""$reset"
                echo "$key_content" >> /etc/dropbear/authorized_keys
                echo "$green""Added key from $key_file to authorized_keys""$reset"
            else
                echo "$yellow""Key from $key_file already exists in authorized_keys, skipping.""$reset"
            end
        end
    end
end

# Restart dropbear to apply changes
echo "$blue""Restarting Dropbear service to apply changes...""$reset"
if test "$DRY_RUN" = "false"
    /etc/init.d/dropbear restart
    echo "$green""Dropbear restarted successfully""$reset"
else
    echo "$yellow""DRY RUN: Skipping Dropbear restart""$reset"
end

# Verify port is properly set
echo "$yellow""Verifying Dropbear configuration...""$reset"
uci get dropbear.@dropbear[0].Port

# Note: Firewall rules for SSH access are now configured in 50-firewall.sh

# Note: UCI commits are handled in 01-install.sh
echo "$green""SSH/Dropbear configuration completed successfully. Changes will be applied during final commit.""$reset"

echo "$yellow""
SECURITY NOTICE:
---------------
SSH access is configured for security:
1. Access ONLY through internal networks and WireGuard VPN
2. NO direct access from WAN
3. For remote access, you must connect to WireGuard VPN first
4. First-boot script will finalize SSH security settings
""$reset"