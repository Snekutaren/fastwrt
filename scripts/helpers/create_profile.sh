#!/usr/bin/fish
# Helper script to create a new configuration profile

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

echo "$purple""FastWrt Configuration Profile Creator""$reset"

# Validate arguments
if test -z "$argv[1]"
    echo "$red""Error: Missing profile name argument""$reset"
    echo "$yellow""Usage: $0 <profile_name> [source_profile]""$reset"
    echo "$yellow""Example: $0 office sne  # Creates 'office' profile based on 'sne'""$reset"
    exit 1
end

# Get profile name from argument
set PROFILE_NAME "$argv[1]"

# Set source profile - use "sne" as default if not specified
if test -n "$argv[2]"
    set SOURCE_PROFILE "$argv[2]"
else
    set SOURCE_PROFILE "sne"
fi

# Determine paths
set BASE_DIR (dirname (dirname (status filename)))
set CONFIG_DIR "$BASE_DIR/scripts/etc/uci-defaults/config"
set PROFILES_DIR "$CONFIG_DIR/profiles"
set PROFILE_DIR "$PROFILES_DIR/$PROFILE_NAME"
set SOURCE_DIR "$PROFILES_DIR/$SOURCE_PROFILE"

echo "$blue""Creating new profile '$PROFILE_NAME' at $PROFILE_DIR""$reset"
echo "$blue""Using '$SOURCE_PROFILE' as template""$reset"

# Check if source profile exists
if not test -d "$SOURCE_DIR"
    echo "$red""Error: Source profile '$SOURCE_PROFILE' not found at $SOURCE_DIR""$reset"
    echo "$yellow""Available profiles:""$reset"
    for dir in $PROFILES_DIR/*/
        if test -d "$dir"
            echo "  - "(basename "$dir")
        end
    end
    exit 1
end

# Check if target profile already exists
if test -d "$PROFILE_DIR"
    echo "$yellow""Warning: Profile '$PROFILE_NAME' already exists at $PROFILE_DIR""$reset"
    echo -n "$yellow""Do you want to overwrite it? [y/N] ""$reset"
    read CONFIRM
    
    if not string match -q -i "y*" "$CONFIRM"
        echo "$red""Operation cancelled.""$reset"
        exit 1
    end
    
    # Create backup of existing profile
    set BACKUP_DIR "$PROFILE_DIR.bak"(date +"%Y%m%d_%H%M%S")
    echo "$yellow""Creating backup of existing profile at $BACKUP_DIR""$reset"
    mv "$PROFILE_DIR" "$BACKUP_DIR"
fi

# Create profile directory
mkdir -p "$PROFILE_DIR"

# Copy files from source profile
echo "$blue""Copying configuration files from '$SOURCE_PROFILE' to '$PROFILE_NAME'...""$reset"
cp -r "$SOURCE_DIR"/* "$PROFILE_DIR"/ 2>/dev/null || true

# Create default files if they don't exist
for file in "wgkeys.fish" "passphrases.fish" "maclist.csv" "rpasswd.fish"
    if not test -f "$PROFILE_DIR/$file"
        echo "$yellow""Creating empty $file file...""$reset"
        
        # Create appropriate template based on file type
        switch "$file"
            case "wgkeys.fish"
                echo "#!/usr/bin/fish
# FastWrt WireGuard Keys - Profile: $PROFILE_NAME
# IMPORTANT: This file contains sensitive key data and should be kept secure

# Server keys - These will be used if present, otherwise generated
# set -gx WG_SERVER_PRIVATE_KEY \"your_persistent_server_private_key_here\"
# set -gx WG_SERVER_PUBLIC_KEY \"your_persistent_server_public_key_here\"

# Client keys - Format: set WG_CLIENT_KEY_NAME \"public_key_value\"
set -gx WG_CLIENT_KEY_EXAMPLE \"example_public_key_here=\"

# IP address allocation for clients
set -gx WG_CLIENT_IP_EXAMPLE \"10.255.0.2\"
" > "$PROFILE_DIR/$file"

            case "passphrases.fish"
                echo "#!/usr/bin/fish
# FastWrt Wireless Passphrases - Profile: $PROFILE_NAME
# IMPORTANT: This file contains sensitive key data and should be kept secure

# Wireless passphrases for different networks
set -gx PASSPHRASE_OPENWRT \"change-this-to-a-strong-passphrase\"
set -gx PASSPHRASE_CLOSEDWRT \"change-this-to-a-different-strong-passphrase\"
set -gx PASSPHRASE_IOTWRT \"change-this-to-another-strong-passphrase\"
set -gx PASSPHRASE_METAWRT \"change-this-to-yet-another-strong-passphrase\"
" > "$PROFILE_DIR/$file"

            case "rpasswd.fish"
                echo "#!/usr/bin/fish
# FastWrt Router Password Configuration - Profile: $PROFILE_NAME
# IMPORTANT: This file contains sensitive password data and should be kept secure

# Router password - Used to set the password for SSH/Web access
# Uncomment and set a strong password:
# set -gx ROUTER_PASSWORD \"your_strong_password_here\"

# If no password is set, a random one will be generated during installation
" > "$PROFILE_DIR/$file"

            case "maclist.csv"
                echo "# MAC Address,IP Address,Device Name,Network
# Format: MAC,IP,Name,Network
# Example for Profile: $PROFILE_NAME
AA:BB:CC:DD:EE:FF,10.0.0.10,admin-laptop,core
AA:BB:CC:DD:EE:00,192.168.90.10,guest-phone,guest
" > "$PROFILE_DIR/$file"
        end
    end
end

echo "$green""Profile '$PROFILE_NAME' created successfully at $PROFILE_DIR""$reset"
echo "$yellow""You can now use it with: ./scripts/etc/uci-defaults/01-install.sh --profile=$PROFILE_NAME""$reset"

# List all available profiles
echo "$blue""Available profiles:""$reset"
for dir in $PROFILES_DIR/*/
    if test -d "$dir"
        if test (basename "$dir") = "$PROFILE_NAME"
            echo "  - "(basename "$dir")" (newly created)"
        else
            echo "  - "(basename "$dir")
        end
    end
end

exit 0
