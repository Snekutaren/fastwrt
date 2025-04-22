#!/usr/bin/fish
# FastWrt Dropbear (SSH) configuration - Pure fish implementation

# Ensure the script runs from its own directory
cd $BASE_DIR
echo "Current working directory: "(pwd)

# Log the purpose of the script
echo "Starting Dropbear configuration script to set up SSH access..."

### --- Dropbear (SSH) ---
echo "Setting Dropbear interface to 'core'..."
uci set dropbear.@dropbear[0].Interface='core'
echo "Setting Dropbear port to '6622'..."
uci set dropbear.@dropbear[0].Port='6622'

# Check if authorized_keys file exists and contains valid keys
if test -f "/etc/dropbear/authorized_keys"; and grep -q "ssh-" "/etc/dropbear/authorized_keys"
    echo "SSH keys found. Setting Dropbear to use key-based authentication only..."
    uci set dropbear.@dropbear[0].PasswordAuth='off'
    uci set dropbear.@dropbear[0].RootPasswordAuth='off'
else
    echo "No SSH keys found. Temporarily enabling password authentication..."
    echo "IMPORTANT: Password authentication will be disabled when running secure_ssh.sh"
    uci set dropbear.@dropbear[0].PasswordAuth='on'
    uci set dropbear.@dropbear[0].RootPasswordAuth='on'
end

# Try to add SSH keys from available sources
echo "Checking for SSH keys to add..."
set ssh_keys_dir "$BASE_DIR/ssh_keys"

if test -d "$ssh_keys_dir"
    # Check for public keys in the ssh_keys directory
    for key_file in $ssh_keys_dir/*.pub
        if test -f "$key_file"
            echo "Found key file: $key_file"
            # Call secure_ssh.sh to add the keys
            source "$BASE_DIR/helpers/secure_ssh.sh"
            break
        end
    end
end

# Restart dropbear to apply changes
echo "Restarting Dropbear service to apply changes..."
/etc/init.d/dropbear restart

# Verify port is properly set
echo "Verifying Dropbear configuration..."
uci get dropbear.@dropbear[0].Port

# Note: Firewall rules for SSH access are now configured in 50-firewall.sh

# Note: UCI commits are handled in 98-commit.sh
echo "SSH/Dropbear configuration completed successfully. Changes will be applied during final commit."

echo "
SECURITY NOTICE:
---------------
SSH access is configured for security:
1. Access ONLY through internal networks and WireGuard VPN
2. NO direct access from WAN
3. For remote access, you must connect to WireGuard VPN first
4. Run secure_ssh.sh to add SSH keys and enhance security further
"