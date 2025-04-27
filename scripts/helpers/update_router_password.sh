#!/usr/bin/fish
# Helper script to update router password in rpasswd.fish and apply it to the system

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

echo "$purple""FastWrt Router Password Update Utility""$reset"

# Base directory determination
set SCRIPT_PATH (status filename)
if string match -q "/*" "$SCRIPT_PATH"
    # Absolute path
    set BASE_DIR (dirname (dirname "$SCRIPT_PATH"))
else
    # Relative path, use pwd
    set BASE_DIR (dirname (dirname (realpath "$SCRIPT_PATH")))
end

# Path to rpasswd.fish
set RPASSWD_FILE "$BASE_DIR/etc/uci-defaults/rpasswd.fish"

# Check if running as root
if test (id -u) -ne 0
    echo "$red""This script must be run as root to update system passwords.""$reset"
    exit 1
end

# Check for existing password file
if test -f "$RPASSWD_FILE"
    echo "$blue""Found existing password file at $RPASSWD_FILE""$reset"
    source "$RPASSWD_FILE"
    
    if set -q ROUTER_PASSWORD
        echo "$yellow""Current password is set but masked for security.""$reset"
        echo "$yellow""Enter a new password or press Enter to keep current password.""$reset"
    else
        echo "$yellow""No password currently set in file.""$reset"
    end
else
    echo "$blue""Creating new password file at $RPASSWD_FILE""$reset"
    # Create directory if it doesn't exist
    mkdir -p (dirname "$RPASSWD_FILE")
end

# Ask for new password
echo "$blue""Enter new router password (or press Enter to generate a random one):""$reset"
read -s new_password

# Generate random password if user didn't provide one
if test -z "$new_password"
    set new_password (openssl rand -base64 12)
    echo "$green""Generated random password: $new_password""$reset"
else
    # Just show that we received input, not the actual password
    echo "$green""Password received (masked for security)""$reset"
end

# Create or update the password file
echo "#!/usr/bin/fish
# FastWrt Router Password Configuration - External password file to separate sensitive data
# IMPORTANT: This file contains sensitive password data and should be kept secure

# This file should be loaded with 'source' from the installation script

# Router password - Used to set the password for SSH/Web access
set -gx ROUTER_PASSWORD \"$new_password\"
" > "$RPASSWD_FILE"

chmod 600 "$RPASSWD_FILE"

# Apply the new password to the system
echo "$blue""Applying new password to system...""$reset"
echo -e "$new_password\n$new_password" | passwd root

echo "$green""Password file updated and system password changed successfully.""$reset"
echo "$yellow""IMPORTANT: Keep $RPASSWD_FILE secure as it contains your router password!""$reset"
