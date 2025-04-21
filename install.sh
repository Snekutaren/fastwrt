#!/bin/sh
# Start with most compatible shell to ensure script runs everywhere
set -e  # Exit on any error

# Confirm script start
echo "install.sh script started."

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
# Check for existing shells and install if missing
echo "Checking for enhanced shells (bash/fish)..."

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

# Determine the best available shell to use
PREFERRED_SHELL="ash"  # Default fallback shell
SHELL_CMD="ash"

# Try to use fish, install if missing and possible
if is_package_installed "fish"; then
  echo "Fish shell is available."
  PREFERRED_SHELL="fish"
elif [ "$FIRMWARE_BUILD" != "true" ]; then  # Only try to install if not building firmware
  echo "Fish shell not found."
  if install_package "fish"; then
    echo "Successfully installed fish shell."
    PREFERRED_SHELL="fish"
  else
    echo "Could not install fish shell, trying bash..."
  fi
fi

# If fish not available, try bash
if [ "$PREFERRED_SHELL" = "ash" ] && is_package_installed "bash"; then
  echo "Bash shell is available."
  PREFERRED_SHELL="bash"
elif [ "$PREFERRED_SHELL" = "ash" ] && [ "$FIRMWARE_BUILD" != "true" ]; then  # Only try to install if not building firmware
  echo "Bash shell not found."
  if install_package "bash"; then
    echo "Successfully installed bash shell."
    PREFERRED_SHELL="bash"
  else
    echo "Could not install bash shell, falling back to ash."
  fi
fi

# Set the shell command based on the preferred shell
case "$PREFERRED_SHELL" in
  "fish")
    SHELL_CMD="fish -c"
    echo "Using fish shell for script execution."
    ;;
  "bash")
    SHELL_CMD="bash"
    echo "Using bash shell for script execution."
    ;;
  *)
    SHELL_CMD="ash"
    echo "Using ash shell for script execution."
    ;;
esac

# Export the preferred shell for other scripts
export PREFERRED_SHELL

# Allow user to specify WireGuard IP and default zone policies
WIREGUARD_IP="10.255.0.1"  # Default WireGuard IP
#
CORE_POLICY_IN="ACCEPT"  # Default Core input policy
CORE_POLICY_OUT="ACCEPT"  # Default Core output policy
CORE_POLICY_FORWARD="REJECT"  # Default Core forward policy
#
OTHER_ZONES_POLICY_IN="DROP"  # Default input policy for other zones
OTHER_ZONES_POLICY_OUT="DROP"  # Default output policy for other zones
OTHER_ZONES_POLICY_FORWARD="DROP"  # Default forward policy for other zones
#
WAN_POLICY_IN="DROP"  # Default WAN input policy
WAN_POLICY_OUT="ACCEPT"  # Default WAN output policy
WAN_POLICY_FORWARD="DROP"  # Default WAN forward policy

# Log the default values
echo "Default WireGuard IP: $WIREGUARD_IP"
echo "Default WAN input policy: $WAN_POLICY_IN"
echo "Default WAN output policy: $WAN_POLICY_OUT"
echo "Default WAN forward policy: $WAN_POLICY_FORWARD"
echo "Default input policy for other zones: $OTHER_ZONES_POLICY_IN"
echo "Default output policy for other zones: $OTHER_ZONES_POLICY_OUT"
echo "Default forward policy for other zones: $OTHER_ZONES_POLICY_FORWARD"
echo "Default Core input policy: $CORE_POLICY_IN"
echo "Default Core output policy: $CORE_POLICY_OUT"
echo "Default Core forward policy: $CORE_POLICY_FORWARD"

# Pass these values as environment variables to scripts
export WIREGUARD_IP
export WAN_POLICY_IN
export WAN_POLICY_OUT
export WAN_POLICY_FORWARD
export OTHER_ZONES_POLICY_IN
export OTHER_ZONES_POLICY_OUT
export OTHER_ZONES_POLICY_FORWARD
export CORE_POLICY_IN
export CORE_POLICY_OUT
export CORE_POLICY_FORWARD

# Debugging: Log the exported variables
echo "Exported WireGuard IP: $WIREGUARD_IP"
echo "Exported WAN input policy: $WAN_POLICY_IN"
echo "Exported WAN output policy: $WAN_POLICY_OUT"
echo "Exported WAN forward policy: $WAN_POLICY_FORWARD"
echo "Exported input policy for other zones: $OTHER_ZONES_POLICY_IN"
echo "Exported output policy for other zones: $OTHER_ZONES_POLICY_OUT"
echo "Exported forward policy for other zones: $OTHER_ZONES_POLICY_FORWARD"
echo "Exported Core input policy: $CORE_POLICY_IN"
echo "Exported Core output policy: $CORE_POLICY_OUT"
echo "Exported Core forward policy: $CORE_POLICY_FORWARD"

# Option to enable WAN6
ENABLE_WAN6=false
export ENABLE_WAN6 # export the variable to scripts
#
echo "WAN6 enabled: $ENABLE_WAN6"

# Option to enable MAC filtering
ENABLE_MAC_FILTERING=true
export ENABLE_MAC_FILTERING # export the variable to scripts
#
echo "MAC filtering enabled: $ENABLE_MAC_FILTERING"


# Define SSIDs and their passphrases
SSID_CLOSEDWRT="ClosedWrt"
SSID_OPENWRT="OpenWrt"
SSID_METAWRT="MetaWrt"
SSID_IOTWRT="IoTWrt"
# Export SSIDs as environment variables
export SSID_OPENWRT
export SSID_CLOSEDWRT
export SSID_IOTWRT
export SSID_METAWRT

# Option to use pregenerated passphrases and set passphrase length
USE_PREGENERATED_PASSPHRASES=true
PASSPHRASE_LENGTH=32
#
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
  echo "Checking for passphrases file in $BASE_DIR..."
  if [ -f "$BASE_DIR/passphrases" ]; then
    echo "Passphrases file found at: $BASE_DIR/passphrases"
    # Source passphrases from the external file
    . "$BASE_DIR/passphrases"
  else
    echo "Error: Passphrases file not found in $BASE_DIR. Please create a 'passphrases' file."
    exit 1
  fi
else
  # Generate new random passphrases
  PASSPHRASE_OPENWRT=$(openssl rand -base64 $PASSPHRASE_LENGTH)
  PASSPHRASE_CLOSEDWRT=$(openssl rand -base64 $PASSPHRASE_LENGTH)
  PASSPHRASE_IOTWRT=$(openssl rand -base64 $PASSPHRASE_LENGTH)
  PASSPHRASE_METAWRT=$(openssl rand -base64 $PASSPHRASE_LENGTH)
fi

# Password validation
# Check if the passphrases meet the length requirement
for passphrase in "$PASSPHRASE_OPENWRT" "$PASSPHRASE_CLOSEDWRT" "$PASSPHRASE_IOTWRT" "$PASSPHRASE_METAWRT"; do
  if [ ${#passphrase} -lt 8 ]; then
    echo "Error: Passphrase too short (minimum 8 characters)."
    exit 1
  fi
  if ! echo "$passphrase" | grep -q '[A-Za-z0-9]'; then
    echo "Error: Passphrase must contain alphanumeric characters."
    exit 1
  fi
done

# Export passphrases as environment variables
export PASSPHRASE_OPENWRT
export PASSPHRASE_CLOSEDWRT
export PASSPHRASE_IOTWRT
export PASSPHRASE_METAWRT

# Log the exported variables
echo "Exported SSID and passphrase for OpenWrt: $SSID_OPENWRT / $PASSPHRASE_OPENWRT"
echo "Exported SSID and passphrase for ClosedWrt: $SSID_CLOSEDWRT / $PASSPHRASE_CLOSEDWRT"
echo "Exported SSID and passphrase for IoTWrt: $SSID_IOTWRT / $PASSPHRASE_IOTWRT"
echo "Exported SSID and passphrase for MetaWrt: $SSID_METAWRT / $PASSPHRASE_METAWRT"

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

# Execute all scripts in the scripts directory using the preferred shell
for script in "$SCRIPTS_DIR"/*.sh; do
  if [ -f "$script" ]; then
    chmod +x "$script"  # Ensure the script is executable
    
    # Update shebang line if needed to match the preferred shell (for bash scripts)
    if [ "$PREFERRED_SHELL" = "bash" ]; then
      # Backup the original script
      cp "$script" "${script}.bak"
      
      # Update the shebang only if it's not already set to bash
      if ! grep -q "^#!/bin/bash" "$script"; then
        sed '1s|^#!/bin/sh|#!/bin/bash|' "${script}.bak" > "$script"
        chmod +x "$script"
        echo "Updated shebang to bash in $script"
      fi
      
      # Remove the backup if successful
      rm "${script}.bak"
    fi
    
    # Adjusted logging for alignment
    echo "Running $script using $PREFERRED_SHELL..."
    
    # Execute based on the preferred shell
    case "$PREFERRED_SHELL" in
      "fish")
        fish -c ". \"$script\""
        ;;
      *)
        # For bash or ash
        $SHELL_CMD "$script"
        ;;
    esac
    
    if [ $? -eq 0 ]; then
      echo "$script executed successfully."
    else
      echo "Error: $script failed to execute."
      exit 1
    fi
  else
    echo "Skipping $script (not a file)"
  fi
done

echo "All scripts executed. Installation complete."
} 2>&1 | tee -a "$LOG_FILE"