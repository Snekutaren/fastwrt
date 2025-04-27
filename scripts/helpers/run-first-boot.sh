#!/usr/bin/fish
# Helper script to manually trigger first-boot configuration

# Set colors for better readability
set green (echo -e "\033[0;32m")
set yellow (echo -e "\033[0;33m")
set red (echo -e "\033[0;31m")
set blue (echo -e "\033[0;34m")
set purple (echo -e "\033[0;35m")
set reset (echo -e "\033[0m")

# Check for root privileges
if test (id -u) -ne 0
    echo "$red""Please run as root""$reset"
    exit 1
end

# Set up environment
set BASE_DIR (dirname (dirname (realpath (status filename))))
set FIRST_BOOT_MARKER "/etc/fastWrt_first_boot_completed"
set FIRST_BOOT_SCRIPT "$BASE_DIR/scripts/etc/uci-defaults/99-first-boot.sh"

echo "$purple""FastWrt First-Boot Configuration Runner""$reset"
echo "$blue""Using base directory: $BASE_DIR""$reset"

# Check if first-boot has already run
if test -f "$FIRST_BOOT_MARKER"
    echo "$yellow""First boot script has already run.""$reset"
    echo -n "$blue""Do you want to run it again? (y/n): ""$reset"
    read response
    
    if test "$response" != "y" -a "$response" != "Y"
        echo "$yellow""Aborting.""$reset"
        exit 0
    fi
    
    echo "$yellow""Removing first boot marker to allow re-execution...""$reset"
    rm -f "$FIRST_BOOT_MARKER"
end

# Check if first-boot script exists
if not test -f "$FIRST_BOOT_SCRIPT"
    echo "$red""First-boot script not found at $FIRST_BOOT_SCRIPT""$reset"
    exit 1
end

echo "$blue""Running first-boot configuration script...""$reset"

# Set standalone mode as an environment variable
set -x STANDALONE_MODE true

# Execute the script
if fish "$FIRST_BOOT_SCRIPT"
    echo "$green""First-boot configuration completed successfully!""$reset"
    exit 0
else
    echo "$red""First-boot configuration failed with exit code $status""$reset"
    exit 1
end
