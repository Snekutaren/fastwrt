#!/usr/bin/fish
# FastWrt Dropbear (SSH) configuration - Implementation using fish shell
# Fish shell is the default shell in FastWrt and should be used for all scripts

# Source common color definitions
source "$PROFILE_DIR/colors.fish"

# Ensure the script runs from its own directory
cd $BASE_DIR
echo "$blue""Current working directory: ""$reset"(pwd)

# Log the purpose of the script
echo "$purple""Starting Dropbear configuration script to set up SSH access...""$reset"

### --- SSH KEY MANAGEMENT ---
echo "$blue""Setting up SSH keys for secure access...""$reset"

# Create required directories
mkdir -p /etc/dropbear
chmod 700 /etc/dropbear

# Create authorized_keys file if it doesn't exist
touch /etc/dropbear/authorized_keys
chmod 600 /etc/dropbear/authorized_keys

# First check for SSH key in standard location
if test -f "/etc/FastWrt/ssh_keys/id_ed25519.pub"
    echo "$green""Found SSH key at /etc/FastWrt/ssh_keys/id_ed25519.pub""$reset"
    cat "/etc/FastWrt/ssh_keys/id_ed25519.pub" >> /etc/dropbear/authorized_keys
    echo "$green""SSH key added successfully from installed id_ed25519.pub""$reset"
else
    # Then check for keys in the profile's ssh_keys directory
    echo "$blue""Looking for keys in $PROFILE_DIR/ssh_keys...""$reset"
    set ssh_keys_dir "$PROFILE_DIR/ssh_keys"
    set keys_found 0
    
    if test -d "$ssh_keys_dir"
        # Check for public keys in the ssh_keys directory
        for key_file in $ssh_keys_dir/*.pub
            if test -f "$key_file"
                echo "$green""Found key file: $key_file""$reset"
                # Add the key without duplication - check if it exists first
                set key_content (cat "$key_file")
                if not grep -qFx "$key_content" "/etc/dropbear/authorized_keys"
                    echo "$blue""Adding key from $key_file to authorized_keys...""$reset"
                    echo "$key_content" >> /etc/dropbear/authorized_keys
                    echo "$green""Added key from $key_file to authorized_keys""$reset"
                    set keys_found (math $keys_found + 1)
                else
                    echo "$yellow""Key from $key_file already exists in authorized_keys, skipping.""$reset"
                    # Count as found since it's already there
                    set keys_found (math $keys_found + 1)
                end
            end
        end
    end
    
    # If still no keys found, check the legacy location as fallback
    if test $keys_found -eq 0
        echo "$yellow""No keys found in profile directory, checking legacy location $BASE_DIR/ssh_keys...""$reset"
        set legacy_ssh_keys_dir "$BASE_DIR/ssh_keys"
        
        if test -d "$legacy_ssh_keys_dir"
            for key_file in $legacy_ssh_keys_dir/*.pub
                if test -f "$key_file"
                    echo "$green""Found legacy key file: $key_file""$reset"
                    # Add the key without duplication - check if it exists first
                    set key_content (cat "$key_file")
                    if not grep -qFx "$key_content" "/etc/dropbear/authorized_keys"
                        echo "$blue""Adding legacy key from $key_file to authorized_keys...""$reset"
                        echo "$key_content" >> /etc/dropbear/authorized_keys
                        echo "$green""Added legacy key from $key_file to authorized_keys""$reset"
                        set keys_found (math $keys_found + 1)
                    else
                        echo "$yellow""Legacy key from $key_file already exists in authorized_keys, skipping.""$reset"
                        # Count as found since it's already there
                        set keys_found (math $keys_found + 1)
                    end
                end
            end
        end
    end
    
    # If no keys found anywhere, generate a new one
    if test $keys_found -eq 0
        echo "$yellow""No SSH keys found, generating a new one...""$reset"
        dropbearkey -t ed25519 -f /etc/dropbear/dropbear_ed25519_key
        dropbearkey -y -f /etc/dropbear/dropbear_ed25519_key | grep "^ssh-ed25519" > /etc/dropbear/authorized_keys
        echo "$green""Generated and added new SSH key""$reset"
        
        # Display the public key for the admin to save
        echo "$yellow""Important: Save this public key for future access:""$reset"
        dropbearkey -y -f /etc/dropbear/dropbear_ed25519_key | grep "^ssh-ed25519"
    end
end

# Ensure proper permissions
chmod 600 /etc/dropbear/authorized_keys

### --- DROPBEAR CONFIGURATION ---
echo "$blue""Configuring Dropbear SSH server...""$reset"

# Set dropbear to use port 6622 on core interface
uci set dropbear.@dropbear[0].Interface='core wireguard'  # Add wireguard interface
uci set dropbear.@dropbear[0].Port='6622'

# Enable key-based auth and disable password auth if we have keys
if grep -q "ssh-" "/etc/dropbear/authorized_keys" 2>/dev/null
    echo "$green""SSH keys found, disabling password authentication""$reset"
    uci set dropbear.@dropbear[0].PasswordAuth='off'
    uci set dropbear.@dropbear[0].RootPasswordAuth='off'
else
    echo "$yellow""No SSH keys found, keeping password authentication enabled for now""$reset"
    # Keep password auth enabled if no SSH keys are present
    uci set dropbear.@dropbear[0].PasswordAuth='on'
    uci set dropbear.@dropbear[0].RootPasswordAuth='on'
    
    # Apply router password if set
    if set -q ROUTER_PASSWORD
        echo "$blue""Setting system password from configuration...""$reset"
        echo -e "$ROUTER_PASSWORD\n$ROUTER_PASSWORD" | passwd root > /dev/null 2>&1
        
        # Mask the actual password in output
        if test "$DEBUG" = "true"
            echo "$yellow""Password set to configured value (visible in debug mode): $ROUTER_PASSWORD""$reset"
        else
            echo "$yellow""Password set to configured value (use --debug to view)""$reset"
        end
    else
        echo "$yellow""No router password configured, not changing system password""$reset"
    end
end

# Check for router password file in multiple locations using profile hierarchy
set ROUTER_PASSWORD_FILES "$PROFILE_DIR/rpasswd.fish" "$DEFAULTS_DIR/rpasswd.fish" "$CONFIG_DIR/rpasswd.fish" "$BASE_DIR/rpasswd.fish"
set ROUTER_PASSWORD_FILE ""

for file_path in $ROUTER_PASSWORD_FILES
    if test -f "$file_path"
        set ROUTER_PASSWORD_FILE "$file_path"
        echo "$blue""Loading router password from: $ROUTER_PASSWORD_FILE""$reset"
        source "$ROUTER_PASSWORD_FILE"
        
        if set -q ROUTER_PASSWORD
            echo "$green""Router password loaded successfully""$reset"
        else
            echo "$yellow""No password set in $ROUTER_PASSWORD_FILE""$reset"
        end
        break
    end
end

# Set other security options
uci set dropbear.@dropbear[0].GatewayPorts='off'  # Prevent binding to non-loopback addresses
uci set dropbear.@dropbear[0].MaxAuthTries='3'    # Limit brute force attempts

# SECURITY EXCEPTION: We commit Dropbear changes immediately to ensure SSH access
# is maintained throughout the configuration process. This prevents lockout scenarios
# where incorrect SSH settings might be applied during the final commit phase.
# This is an intentional deviation from the centralized commit architecture.
if test "$DRY_RUN" != "true"
    echo "$yellow""SECURITY EXCEPTION: Committing Dropbear changes immediately to maintain SSH access...""$reset"
    uci commit dropbear
else
    echo "$yellow""DRY RUN: Skipping Dropbear commit""$reset"
end

# Restart dropbear to apply changes
echo "$blue""Restarting Dropbear service to apply changes...""$reset"
if test "$DRY_RUN" != "true"
    /etc/init.d/dropbear restart
    echo "$green""Dropbear restarted successfully""$reset"
else
    echo "$yellow""DRY RUN: Skipping Dropbear restart""$reset"
end

# Verify port is properly set
echo "$yellow""Verifying Dropbear configuration:""$reset"
echo "Interface: "(uci get dropbear.@dropbear[0].Interface)
echo "Port: "(uci get dropbear.@dropbear[0].Port)
echo "Password auth: "(uci get dropbear.@dropbear[0].PasswordAuth)

echo "$green""SSH/Dropbear configuration completed successfully.""$reset"

echo "$yellow""
SECURITY NOTICE:
---------------
SSH access is configured for security:
1. Access ONLY through internal networks and WireGuard VPN
2. NO direct access from WAN
3. For remote access, you must connect to WireGuard VPN first
4. SSH firewall rules are configured in 50-firewall.sh
""$reset"