#!/usr/bin/fish
# Helper script to create the modular structure for FastWrt

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

echo "$purple""FastWrt Modular Directory Structure Setup""$reset"

# Determine base directory
set BASE_DIR (dirname (dirname (status filename)))
set CONFIG_DIR "$BASE_DIR/scripts/etc/uci-defaults/config"
set PROFILES_DIR "$CONFIG_DIR/profiles"

# Create directory structure
echo "$blue""Creating modular directory structure...""$reset"
mkdir -p "$CONFIG_DIR"
mkdir -p "$PROFILES_DIR"
mkdir -p "$PROFILES_DIR/sne"

# Add a .gitkeep file to ensure the directory structure is maintained
touch "$PROFILES_DIR/.gitkeep"

# Migrate existing configuration files if they exist
echo "$blue""Checking for legacy configuration files to migrate...""$reset"

# Files to migrate from base directory
set MIGRATE_FILES "wgkeys.fish" "passphrases.fish" "maclist.csv" "rpasswd.fish"

for file in $MIGRATE_FILES
    if test -f "$BASE_DIR/scripts/etc/uci-defaults/$file"
        echo "$yellow""Found legacy $file file, copying to sne profile...""$reset"
        cp "$BASE_DIR/scripts/etc/uci-defaults/$file" "$PROFILES_DIR/sne/$file"
    else if test -f "$BASE_DIR/$file"
        echo "$yellow""Found legacy $file file in base directory, copying to sne profile...""$reset"
        cp "$BASE_DIR/$file" "$PROFILES_DIR/sne/$file"
    else
        echo "$blue""No legacy $file file found, creating template...""$reset"
        
        # Create appropriate template based on file type
        switch "$file"
            case "wgkeys.fish"
                echo "#!/usr/bin/fish
# FastWrt WireGuard Keys - Profile: sne
# IMPORTANT: This file contains sensitive key data and should be kept secure

# Server keys - These will be used if present, otherwise generated
# set -gx WG_SERVER_PRIVATE_KEY \"your_persistent_server_private_key_here\"
# set -gx WG_SERVER_PUBLIC_KEY \"your_persistent_server_public_key_here\"

# Client keys - Format: set WG_CLIENT_KEY_NAME \"public_key_value\"
set -gx WG_CLIENT_KEY_S10 \"79x+3JAe1T2/OW4UiuVmoVzy++f09u8Cgrbf8fsrJD0=\"
set -gx WG_CLIENT_KEY_ROG \"csOqRa/pBMsPWcas+Od2vrJb5YHd83V4XVtJPm6X4Qg=\"

# Example key - Only used as documentation
set -gx WG_CLIENT_KEY_EXAMPLE \"4H/Bhi5RevX5Rw5vQdE+MyDEDEXAMPLEPUBKEY1234567890=\"

# IP address allocation for clients
set -gx WG_CLIENT_IP_S10 \"10.255.0.2\"
set -gx WG_CLIENT_IP_ROG \"10.255.0.3\"
set -gx WG_CLIENT_IP_EXAMPLE \"10.255.0.2\"
" > "$PROFILES_DIR/sne/$file"

            case "passphrases.fish"
                echo "#!/usr/bin/fish
# FastWrt Wireless Passphrases - Profile: sne
# IMPORTANT: This file contains sensitive key data and should be kept secure

# Wireless passphrases for different networks
set -gx PASSPHRASE_OPENWRT \"change-this-to-a-strong-passphrase\"
set -gx PASSPHRASE_CLOSEDWRT \"change-this-to-a-different-strong-passphrase\"
set -gx PASSPHRASE_IOTWRT \"change-this-to-another-strong-passphrase\"
set -gx PASSPHRASE_METAWRT \"change-this-to-yet-another-strong-passphrase\"
" > "$PROFILES_DIR/sne/$file"

            case "rpasswd.fish"
                echo "#!/usr/bin/fish
# FastWrt Router Password Configuration - Profile: sne
# IMPORTANT: This file contains sensitive password data and should be kept secure

# Router password - Used to set the password for SSH/Web access
# set -gx ROUTER_PASSWORD \"your_strong_password_here\"
" > "$PROFILES_DIR/sne/$file"

            case "maclist.csv"
                echo "# MAC Address,IP Address,Device Name,Network
# Format: MAC,IP,Name,Network
# Example for Profile: sne
AA:BB:CC:DD:EE:FF,10.0.0.10,admin-laptop,core
AA:BB:CC:DD:EE:00,192.168.90.10,guest-phone,guest
" > "$PROFILES_DIR/sne/$file"
        end
    end
end

# Create colors.fish in the sne profile if it exists in config/defaults
if test -f "$CONFIG_DIR/defaults/colors.fish"
    echo "$yellow""Found colors.fish in defaults, copying to sne profile...""$reset"
    cp "$CONFIG_DIR/defaults/colors.fish" "$PROFILES_DIR/sne/colors.fish"
end

# Create the 'sne' profile directory structure and ensure ssh_keys folder exists
echo "$blue""Creating ssh_keys directory in sne profile...""$reset"
mkdir -p "$PROFILES_DIR/sne/ssh_keys"

# If keys exist in the old location, copy them to the new one
if test -d "$BASE_DIR/scripts/etc/uci-defaults/ssh_keys"
    echo "$yellow""Found SSH keys in the legacy location. Copying to profile directory...""$reset"
    cp -r "$BASE_DIR/scripts/etc/uci-defaults/ssh_keys/"* "$PROFILES_DIR/sne/ssh_keys/" 2>/dev/null || true
    echo "$green""SSH keys migrated to profile directory""$reset"
fi

echo "$green""Modular directory structure created successfully!""$reset"
echo "$blue""Default 'sne' profile is ready to use.""$reset"
echo "$yellow""You can now use profiles with: ./scripts/etc/uci-defaults/01-install.sh --profile=sne""$reset"

# Create a second "other" example profile
echo "$blue""Creating example 'other' profile...""$reset"
mkdir -p "$PROFILES_DIR/other"

for file in $MIGRATE_FILES
    cp "$PROFILES_DIR/sne/$file" "$PROFILES_DIR/other/$file"
    # Replace "sne" with "other" in the file content
    sed -i "s/Profile: sne/Profile: other/g" "$PROFILES_DIR/other/$file"
end

# Also create ssh_keys dir in the 'other' example profile
mkdir -p "$PROFILES_DIR/other/ssh_keys"

echo "$green""Example 'other' profile created.""$reset"
echo "$yellow""Available profiles:""$reset"
echo "  - sne (default)"
echo "  - other (example)"

echo "$purple""Setup complete!""$reset"
