#!/usr/bin/fish
# Helper functions for safely managing services in FastWrt scripts

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
    set reset (echo -e "\033[0m")
end

# Function to safely restart a service with dry run awareness
function safe_service_restart
    set service_name $argv[1]
    
    # Check if we're in dry run mode
    if test "$DRY_RUN" = "true"; or test "$UCI_DRY_RUN" = "true"; or test -f /tmp/fastwrt_dry_run.lock
        echo "$yellow""DRY RUN: Would restart $service_name service""$reset"
        return 0
    end
    
    echo "$blue""Restarting $service_name...""$reset"
    if /etc/init.d/$service_name restart
        echo "$green""$service_name restarted successfully""$reset"
        return 0
    else
        echo "$red""WARNING: $service_name restart failed""$reset"
        return 1
    end
end

# Function to safely reload a service with dry run awareness
function safe_service_reload
    set service_name $argv[1]
    
    # Check if we're in dry run mode - multiple checks for robustness
    if test "$DRY_RUN" = "true"; or test "$UCI_DRY_RUN" = "true"; or test -f /tmp/fastwrt_dry_run.lock
        echo "$yellow""DRY RUN: Would reload $service_name service""$reset"
        return 0
    end
    
    echo "$blue""Reloading $service_name...""$reset"
    if /etc/init.d/$service_name reload
        echo "$green""$service_name reloaded successfully""$reset"
        return 0
    else
        echo "$red""WARNING: $service_name reload failed""$reset"
        return 1
    end
end

# Function to check if a package can be safely installed in dry run mode
function safe_package_install
    set package_name $argv[1]
    
    # Check if we're in dry run mode
    if test "$DRY_RUN" = "true"; or test "$UCI_DRY_RUN" = "true"; or test -f /tmp/fastwrt_dry_run.lock
        echo "$yellow""DRY RUN: Would install $package_name package""$reset"
        return 0
    end
    
    echo "$blue""Installing $package_name...""$reset"
    if opkg install $package_name
        echo "$green""$package_name installed successfully""$reset"
        return 0
    else
        echo "$red""WARNING: $package_name installation failed""$reset"
        return 1
    end
end
