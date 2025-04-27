#!/usr/bin/fish

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

echo "$purple""FastWrt Configuration Organizer""$reset"
echo "$blue""This script will organize configuration files into the modular structure""$reset"

# Determine base directory
set BASE_DIR (dirname (dirname (dirname (status filename))))
echo "$blue""Base directory: $BASE_DIR""$reset"

# Set paths
set UCI_DEFAULTS_DIR "$BASE_DIR/scripts/etc/uci-defaults"
set CONFIG_DIR "$UCI_DEFAULTS_DIR/config"
set DEFAULTS_DIR "$CONFIG_DIR/defaults"

# Create directory structure
echo "$blue""Creating directory structure...""$reset"
mkdir -p "$DEFAULTS_DIR"

# Configuration files to move
set CONFIG_FILES "wgkeys.fish" "rpasswd.fish"
set ROOT_DIR_FILES "passphrases.fish" "maclist.csv"

# Move UCI defaults files
echo "$blue""Moving configuration files from uci-defaults...""$reset"
for file in $CONFIG_FILES
    if test -f "$UCI_DEFAULTS_DIR/$file"
        echo "$green""Moving $file to $DEFAULTS_DIR""$reset"
        cp "$UCI_DEFAULTS_DIR/$file" "$DEFAULTS_DIR/"
        chmod --reference="$UCI_DEFAULTS_DIR/$file" "$DEFAULTS_DIR/$file"
        echo "$yellow""NOTE: Original file kept for backward compatibility""$reset"
    else
        echo "$yellow""File $file not found, creating template...""$reset"
        
        # Create template file based on file type
        switch "$file"
            case "wgkeys.fish"
                echo "#!/usr/bin/fish
# FastWrt WireGuard Keys - External key file to separate keys from main script
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
" > "$DEFAULTS_DIR/$file"
            case "rpasswd.fish"
                echo "#!/usr/bin/fish
# FastWrt Router Password Configuration - External password file to separate sensitive data
# IMPORTANT: This file contains sensitive password data and should be kept secure

# Router password - Used to set the password for SSH/Web access
# set -gx ROUTER_PASSWORD \"your_strong_password_here\"
" > "$DEFAULTS_DIR/$file"
        end
        
        chmod 600 "$DEFAULTS_DIR/$file"
        echo "$green""Created template for $file""$reset"
    end
end

# Move root dir config files
echo "$blue""Moving configuration files from base directory...""$reset"
for file in $ROOT_DIR_FILES
    if test -f "$BASE_DIR/$file"
        echo "$green""Moving $file to $DEFAULTS_DIR""$reset"
        cp "$BASE_DIR/$file" "$DEFAULTS_DIR/"
        chmod --reference="$BASE_DIR/$file" "$DEFAULTS_DIR/$file"
        echo "$yellow""NOTE: Original file kept for backward compatibility""$reset"
    else
        echo "$yellow""File $file not found in base directory""$reset"
        
        # Create template files if needed
        switch "$file"
            case "passphrases.fish"
                echo "#!/usr/bin/fish
# FastWrt Wireless Passphrases - External file to separate sensitive data
# IMPORTANT: This file contains sensitive key data and should be kept secure

# Wireless passphrases for different networks
set -gx PASSPHRASE_OPENWRT \"change-this-to-a-strong-passphrase\"
set -gx PASSPHRASE_CLOSEDWRT \"change-this-to-a-different-strong-passphrase\"
set -gx PASSPHRASE_IOTWRT \"change-this-to-another-strong-passphrase\"
set -gx PASSPHRASE_METAWRT \"change-this-to-yet-another-strong-passphrase\"
" > "$DEFAULTS_DIR/$file"
                chmod 600 "$DEFAULTS_DIR/$file"
                echo "$green""Created template for $file""$reset"
            case "maclist.csv"
                echo "# MAC Address,IP Address,Device Name,Network
# Format: MAC,IP,Name,Network
# Example:
AA:BB:CC:DD:EE:FF,10.0.0.10,admin-laptop,core
AA:BB:CC:DD:EE:00,192.168.90.10,guest-phone,guest
" > "$DEFAULTS_DIR/$file"
                echo "$green""Created template for $file""$reset"
        end
    end
end

# Create config_paths.fish
echo "$blue""Creating config_paths.fish...""$reset"
echo "#!/usr/bin/fish
# FastWrt Configuration Paths - Central configuration for the modular system

# Base configuration directory
set -gx CONFIG_DIR (dirname (status filename))
set -gx DEFAULTS_DIR \"\$CONFIG_DIR/defaults\"

# Device selection - uncomment and set to your device model
# set -gx DEVICE_MODEL \"GL-MT300N-V2\"

# Network profile selection - uncomment and set to your preferred network profile
# set -gx NETWORK_PROFILE \"home\"

# User profile selection - uncomment and set to your username
# set -gx USER_PROFILE \"john\"

# Print configuration paths
if status --is-interactive
    echo \"Configuration paths:\"
    echo \"CONFIG_DIR: \$CONFIG_DIR\"
    echo \"DEFAULTS_DIR: \$DEFAULTS_DIR\"
    
    if set -q DEVICE_MODEL
        echo \"DEVICE_MODEL: \$DEVICE_MODEL\"
    else
        echo \"DEVICE_MODEL: Not set (using defaults only)\"
    end
    
    if set -q NETWORK_PROFILE
        echo \"NETWORK_PROFILE: \$NETWORK_PROFILE\"
    else
        echo \"NETWORK_PROFILE: Not set (using defaults only)\"
    end
    
    if set -q USER_PROFILE
        echo \"USER_PROFILE: \$USER_PROFILE\"
    else
        echo \"USER_PROFILE: Not set (using defaults only)\"
    end
end
" > "$CONFIG_DIR/config_paths.fish"

echo "$green""Created config_paths.fish""$reset"

# Update 01-install.sh to handle the new structure
echo "$purple""Configuration structure created successfully!""$reset"
echo "$yellow""Next steps:""$reset"
echo "1. Update 01-install.sh to search for configuration files in multiple locations"
echo "2. Update other scripts to use the CONFIG_DIR environment variable"
echo "3. Test the changes with the --dry-run option"

echo "$green""Complete!""$reset"
