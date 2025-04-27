#!/usr/bin/fish
# Helper script to add a new WireGuard client to the keys file

# Source colors from profile directory or use defaults
set COLORS_FILES "$PROFILE_DIR/colors.fish" "$DEFAULTS_DIR/colors.fish" "$CONFIG_DIR/colors.fish" "$BASE_DIR/colors.fish" "$BASE_DIR/scripts/etc/uci-defaults/config/profiles/sne/colors.fish"
for file_path in $COLORS_FILES
    if test -f "$file_path"
        source "$file_path"
        break
    end
end

# Fallback if colors not loaded
if not set -q green
    set green (echo -e "\033[0;32m")
    set yellow (echo -e "\033[0;33m")
    set red (echo -e "\033[0;31m")
    set blue (echo -e "\033[0;34m")
    set purple (echo -e "\033[0;35m")
    set reset (echo -e "\033[0m")
end

# Verify path to wgkeys.fish file
if test -z "$1"
    set WG_KEYS_FILE "/etc/uci-defaults/wgkeys.fish"
    echo "$yellow""Using default path: $WG_KEYS_FILE""$reset"
else
    set WG_KEYS_FILE "$1"
    echo "$blue""Using specified path: $WG_KEYS_FILE""$reset"
end

if not test -f "$WG_KEYS_FILE"
    echo "$red""ERROR: WireGuard keys file not found at $WG_KEYS_FILE""$reset"
    echo "$yellow""Please provide the correct path to wgkeys.fish""$reset"
    exit 1
end

# Query for client information
echo "$purple""Adding new WireGuard client""$reset"
echo "$blue""Please enter the client name (alphanumeric only, no spaces):""$reset"
read CLIENT_NAME

# Validate client name
if not string match -qr "^[a-zA-Z0-9_]+$" -- "$CLIENT_NAME"
    echo "$red""ERROR: Invalid client name. Use only letters, numbers, and underscores.""$reset"
    exit 1
end

# Check if client already exists
if grep -q "WG_CLIENT_KEY_$CLIENT_NAME" "$WG_KEYS_FILE"
    echo "$red""ERROR: Client $CLIENT_NAME already exists in the keys file.""$reset"
    echo "$yellow""To update this client, remove it first or edit the file directly.""$reset"
    exit 1
end

# Enter public key
echo "$blue""Enter the client's public key:""$reset"
read CLIENT_KEY

# Validate public key format (basic check)
if not string match -qr "^[A-Za-z0-9+/]{42,44}=$" -- "$CLIENT_KEY"
    echo "$red""WARNING: The provided key doesn't appear to be in the correct format.""$reset"
    echo "$yellow""A WireGuard public key should be 44 characters ending with '='""$reset"
    echo "$blue""Do you want to continue anyway? (y/n)""$reset"
    read CONTINUE
    if not string match -qr "^[Yy]" -- "$CONTINUE" 
        echo "$red""Aborting operation.""$reset"
        exit 1
    end
end

# Enter IP address
echo "$blue""Enter the client IP address in the WireGuard subnet (default: 10.255.0.x):""$reset"
read CLIENT_IP

# Validate IP format (basic check)
if not string match -qr "^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$" -- "$CLIENT_IP"
    echo "$red""ERROR: Invalid IP address format.""$reset"
    exit 1
end

# Add the new client to the keys file
echo "" >> "$WG_KEYS_FILE"
echo "# Client added on "(date) >> "$WG_KEYS_FILE"
echo "set -gx WG_CLIENT_KEY_$CLIENT_NAME \"$CLIENT_KEY\"" >> "$WG_KEYS_FILE"
echo "set -gx WG_CLIENT_IP_$CLIENT_NAME \"$CLIENT_IP\"" >> "$WG_KEYS_FILE"

# Add a security warning about sensitive information management
if test -f "$WG_KEYS_FILE"
    echo "$orange""SECURITY NOTE: The WireGuard keys file contains sensitive information.""$reset"
    echo "$orange""           Make sure it's stored in a secure location with restricted access.""$reset"
    
    # Check if the file contains private keys
    if grep -q "PRIVATE_KEY" "$WG_KEYS_FILE"
        echo "$red""WARNING: This file contains private keys which should be kept secret!""$reset"
    end
end

echo "$green""Successfully added client $CLIENT_NAME to $WG_KEYS_FILE""$reset"
echo "$yellow""You need to run the WireGuard configuration script to apply this change.""$reset"
echo "$blue""Command: ./scripts/etc/uci-defaults/55-wireguard.sh""$reset"

exit 0
