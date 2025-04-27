#!/usr/bin/fish
# Helper script to save current WireGuard server keys to wgkeys.fish for persistence between reflashes

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

echo "$purple""WireGuard Key Persistence Helper""$reset"

# Determine paths with profile support
set SERVER_PRIVATE_KEY_FILE "/etc/wireguard/server_private.key"
set SERVER_PUBLIC_KEY_FILE "/etc/wireguard/server_public.key"

# Determine config location - prefer active profile if set
if set -q CONFIG_PROFILE
    set PROFILE_DIR "/etc/uci-defaults/config/profiles/$CONFIG_PROFILE"
    set WG_KEYS_FILE "$PROFILE_DIR/wgkeys.fish"
    echo "$blue""Using profile config location: $WG_KEYS_FILE""$reset"
else
    # Try to find the best location for saving keys
    set BASE_DIR "/etc/uci-defaults"
    set CONFIG_DIR "$BASE_DIR/config"
    set PROFILES_DIR "$CONFIG_DIR/profiles"
    
    # Check for sne profile as default
    if test -d "$PROFILES_DIR/sne"
        set WG_KEYS_FILE "$PROFILES_DIR/sne/wgkeys.fish"
        echo "$yellow""No profile specified, using default 'sne' profile: $WG_KEYS_FILE""$reset"
    else
        set WG_KEYS_FILE "$BASE_DIR/wgkeys.fish"
        echo "$yellow""No profile structure found, using legacy location: $WG_KEYS_FILE""$reset"
    end
fi

# Create directory if it doesn't exist
mkdir -p (dirname "$WG_KEYS_FILE")

# Check if the server keys exist
if not test -f "$SERVER_PRIVATE_KEY_FILE"; or not test -f "$SERVER_PUBLIC_KEY_FILE"
    echo "$red""ERROR: Server keys not found at $SERVER_PRIVATE_KEY_FILE and $SERVER_PUBLIC_KEY_FILE""$reset"
    echo "$yellow""Please make sure WireGuard is properly configured first.""$reset"
    exit 1
end

# Read current server keys
set SERVER_PRIVATE_KEY (cat "$SERVER_PRIVATE_KEY_FILE")
set SERVER_PUBLIC_KEY (cat "$SERVER_PUBLIC_KEY_FILE")

if test -z "$SERVER_PRIVATE_KEY"; or test -z "$SERVER_PUBLIC_KEY"
    echo "$red""ERROR: Server keys are empty""$reset"
    exit 1
end

echo "$blue""Found valid WireGuard server keys""$reset"

# Check if wgkeys.fish file exists
if not test -f "$WG_KEYS_FILE"
    echo "$yellow""WireGuard keys file not found at $WG_KEYS_FILE""$reset"
    echo "$yellow""Creating new file...""$reset"
    
    # Create basic file structure
    echo "#!/usr/bin/fish
# FastWrt WireGuard Keys - External key file to separate keys from main script
# IMPORTANT: This file contains sensitive key data and should be kept secure

# This file should be loaded with 'source' from the wireguard script
" > "$WG_KEYS_FILE"
fi

# Read current file content
set FILE_CONTENT (cat "$WG_KEYS_FILE")

# Check if server keys are already in the file
set SERVER_KEYS_EXIST 0
if string match -q "*WG_SERVER_PRIVATE_KEY*" -- "$FILE_CONTENT"
    set SERVER_KEYS_EXIST 1
end

if test "$SERVER_KEYS_EXIST" -eq 1
    echo "$yellow""Server keys already exist in $WG_KEYS_FILE""$reset"
    echo "$yellow""Would you like to update them? [y/N]""$reset"
    read UPDATE_KEYS
    
    if not string match -q "[Yy]*" -- "$UPDATE_KEYS"
        echo "$blue""Keeping existing keys in $WG_KEYS_FILE""$reset"
        exit 0
    end
    
    # Remove existing server key definitions
    set TEMP_FILE "/tmp/wgkeys_temp.fish"
    grep -v "WG_SERVER_.*_KEY" "$WG_KEYS_FILE" > "$TEMP_FILE"
    mv "$TEMP_FILE" "$WG_KEYS_FILE"
    
    echo "$green""Previous server key definitions removed""$reset"
end

# Add server keys to the top of the file, after the header comments
set TEMP_FILE "/tmp/wgkeys_temp.fish"
set HEADER_LINES 6  # Number of header comment lines
head -n $HEADER_LINES "$WG_KEYS_FILE" > "$TEMP_FILE"
echo "
# Server keys - These will be used if present, otherwise generated
set -gx WG_SERVER_PRIVATE_KEY \"$SERVER_PRIVATE_KEY\"
set -gx WG_SERVER_PUBLIC_KEY \"$SERVER_PUBLIC_KEY\"
" >> "$TEMP_FILE"
tail -n +$HEADER_LINES "$WG_KEYS_FILE" | grep -v "^$" | grep -v "^# Server keys" >> "$TEMP_FILE"
mv "$TEMP_FILE" "$WG_KEYS_FILE"

echo "$green""Server keys have been saved to $WG_KEYS_FILE""$reset"
echo "$green""These keys will now persist across reflashes as long as you include this file.""$reset"

# Set proper permissions
chmod 600 "$WG_KEYS_FILE"
echo "$yellow""IMPORTANT: Keep this file secure as it contains your private key!""$reset"
