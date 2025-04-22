#!/bin/sh
# Start with most compatible shell to ensure script runs everywhere
set -e  # Exit on any error

# Confirm script start
echo "FastWrt Configuration Running from: $(cd "$(dirname "$0")" && pwd)"
echo "Current time: $(date)"

# Default configuration
DEBUG_MODE=false
DRY_RUN=false

# Parse command line arguments
for arg in "$@"; do
  case $arg in
    --debug)
      DEBUG_MODE=true
      echo "Debug mode enabled"
      export DEBUG=true
      ;;
    --dry-run)
      DRY_RUN=true
      echo "Dry run mode enabled - no changes will be committed"
      export DRY_RUN=true
      ;;
  esac
done

# Define log file
LOG_FILE="install_$(date +%Y%m%d_%H%M%S).log"
echo "Logging installation process to $LOG_FILE"

# Set up logging in a POSIX-compliant way that displays output on both console and log file
{
# Ensure the script is executed with root privileges
if [ "$(id -u)" -ne 0 ]; then
  echo "Please run as root"
  exit 1
fi

# Define the base directory of the script and export it
BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
export BASE_DIR

# Log the current working directory
echo "Current working directory: $(pwd)"

##############################################
# Shell Selection and Installation Logic
##############################################
# Check for fish shell and install if missing
echo "Checking for fish shell..."

# Function to check if a package is installed
is_package_installed() {
  local pkg_name="$1"
  if command -v opkg >/dev/null 2>&1; then
    opkg list-installed | grep -q "^$pkg_name "
    return $?
  else
    command -v "$pkg_name" >/dev/null 2>&1
    return $?
  fi
}

# Function to install a package
install_package() {
  local pkg_name="$1"
  echo "Attempting to install $pkg_name..."
  if command -v opkg >/dev/null 2>&1; then
    echo "Using opkg to install $pkg_name..."
    opkg update
    opkg install "$pkg_name"
    return $?
  else
    echo "Package manager opkg not found. Cannot install $pkg_name."
    return 1
  fi
}

# Check for fish shell and install if missing
if is_package_installed "fish"; then
  echo "Fish shell is available."
else
  echo "Fish shell not found. Installing..."
  if install_package "fish"; then
    echo "Successfully installed fish shell."
  else
    echo "ERROR: Could not install fish shell. Please install manually with 'opkg install fish'."
    exit 1
  fi
fi

# Also install bash for fallback (if needed)
if ! is_package_installed "bash"; then
  echo "Installing bash as fallback shell..."
  install_package "bash" || echo "Warning: Could not install bash. Using ash as fallback."
fi

# Set environment variables using fish syntax
# Create a fish script to set up the environment
FISH_ENV_SCRIPT="$BASE_DIR/env.fish"
cat > "$FISH_ENV_SCRIPT" <<'EOF'
#!/usr/bin/fish

# Set environment variables for the configuration
set -gx BASE_DIR "$BASE_DIR"

# Pass through dry run mode and debug flags if set
if test "$DRY_RUN" = "true"
  set -gx DRY_RUN true
  echo "Fish environment: DRY RUN mode enabled"
else
  set -gx DRY_RUN false
end

if test "$DEBUG" = "true"
  set -gx DEBUG true
else
  set -gx DEBUG false
end

# Default configuration values
set -gx WIREGUARD_IP "10.255.0.1"
set -gx CORE_POLICY_IN "ACCEPT" 
set -gx CORE_POLICY_OUT "ACCEPT" 
set -gx CORE_POLICY_FORWARD "REJECT"
set -gx OTHER_ZONES_POLICY_IN "DROP"
set -gx OTHER_ZONES_POLICY_OUT "DROP"
set -gx OTHER_ZONES_POLICY_FORWARD "DROP"
set -gx WAN_POLICY_IN "DROP"
set -gx WAN_POLICY_OUT "ACCEPT"
set -gx WAN_POLICY_FORWARD "DROP"

# Option to enable WAN6
set -gx ENABLE_WAN6 false

# Option to enable MAC filtering
set -gx ENABLE_MAC_FILTERING true

# SSIDs
set -gx SSID_CLOSEDWRT "ClosedWrt"
set -gx SSID_OPENWRT "OpenWrt"
set -gx SSID_METAWRT "MetaWrt"
set -gx SSID_IOTWRT "IoTWrt"

# Don't print these variables every time, just once at the beginning
if status --is-interactive; and not set -q ENVIRONMENT_PRINTED
  # Print environment variables only once
  set -gx ENVIRONMENT_PRINTED 1
  
  echo "Configuration environment set up."
  echo "BASE_DIR: $BASE_DIR"
  echo "DRY_RUN: $DRY_RUN"
  echo "DEBUG: $DEBUG"
  echo "Core policies: $CORE_POLICY_IN/$CORE_POLICY_OUT/$CORE_POLICY_FORWARD"
  echo "WAN policies: $WAN_POLICY_IN/$WAN_POLICY_OUT/$WAN_POLICY_FORWARD"
  echo "ENABLE_WAN6: $ENABLE_WAN6"
  echo "ENABLE_MAC_FILTERING: $ENABLE_MAC_FILTERING"
  echo "SSIDs: $SSID_OPENWRT, $SSID_CLOSEDWRT, $SSID_METAWRT, $SSID_IOTWRT"
end
EOF

# Option to use pregenerated passphrases and set passphrase length
USE_PREGENERATED_PASSPHRASES=true
PASSPHRASE_LENGTH=32
echo "Using pregenerated passphrases: $USE_PREGENERATED_PASSPHRASES"
echo "Passphrase length: $PASSPHRASE_LENGTH"

# Debugging: Check if the maclist file exists and log its absolute path
MACLIST_PATH="$BASE_DIR/maclist.csv"
if [ -f "$MACLIST_PATH" ]; then
  echo "Maclist file found at: $MACLIST_PATH"
else
  echo "Error: Maclist file not found at $MACLIST_PATH. Please create a 'maclist.csv' file."
  exit 1
fi

# Ensure the logic correctly handles the USE_PREGENERATED_PASSPHRASES variable
# Check if pregenerated passphrases should be used
# Debugging: Check if the passphrases file exists and log its absolute path
if [ "$USE_PREGENERATED_PASSPHRASES" = "true" ]; then
  echo "Checking for fish-compatible passphrases file in $BASE_DIR..."
  if [ -f "$BASE_DIR/passphrases.fish" ]; then
    echo "Fish-compatible passphrases file found at: $BASE_DIR/passphrases.fish"
    # The fish script will source this directly, no need to add it to the env script
  else
    echo "Error: Fish-compatible passphrases file not found in $BASE_DIR. Please create a 'passphrases.fish' file."
    exit 1
  fi
else
  # Generate new random passphrases with fish syntax
  echo "# Generating random passphrases" >> "$FISH_ENV_SCRIPT"
  echo "set -gx PASSPHRASE_OPENWRT \"$(openssl rand -base64 $PASSPHRASE_LENGTH)\"" >> "$FISH_ENV_SCRIPT"
  echo "set -gx PASSPHRASE_CLOSEDWRT \"$(openssl rand -base64 $PASSPHRASE_LENGTH)\"" >> "$FISH_ENV_SCRIPT"
  echo "set -gx PASSPHRASE_IOTWRT \"$(openssl rand -base64 $PASSPHRASE_LENGTH)\"" >> "$FISH_ENV_SCRIPT"
  echo "set -gx PASSPHRASE_METAWRT \"$(openssl rand -base64 $PASSPHRASE_LENGTH)\"" >> "$FISH_ENV_SCRIPT"
fi

# Debug: Print the environment script contents for verification
echo "Generated fish environment script contents:"
cat "$FISH_ENV_SCRIPT"

# Define the scripts directory using the absolute path from BASE_DIR
SCRIPTS_DIR="$BASE_DIR/scripts"
# Check if the scripts directory exists
if [ ! -d "$SCRIPTS_DIR" ]; then
  echo "Scripts directory not found: $SCRIPTS_DIR"
  exit 1
fi
echo "Scripts directory: $SCRIPTS_DIR"
echo "Scripts to execute:"
ls -l "$SCRIPTS_DIR"/*.sh

# Execute each script with fish
echo "Executing configuration scripts with fish shell..."
for script in "$SCRIPTS_DIR"/*.sh; do
  if [ -f "$script" ]; then
    chmod +x "$script"  # Ensure the script is executable
    script_name=$(basename "$script")
    echo "Running $script_name with fish shell..."
    
    # Execute the script with fish
    # Pass the script as a parameter to fish rather than using exec
    fish -C "source $FISH_ENV_SCRIPT" "$script"
    script_status=$?
    
    if [ $script_status -eq 0 ]; then
      echo "$script_name executed successfully."
    else
      echo "Error: $script_name failed to execute (exit code: $script_status)."
      exit 1
    fi
  else
    echo "Skipping $script (not a file)"
  fi
done

# Clean up
rm -f "$FISH_ENV_SCRIPT"

echo "All scripts executed. Installation complete."
} 2>&1 | tee -a "$LOG_FILE"

# Final message outside of logging
echo "Installation process completed. Log saved to $LOG_FILE"