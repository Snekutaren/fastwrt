#!/bin/sh

# Debugging: Confirm script start
echo "install.sh script started."

# Allow user to specify WireGuard IP and default zone policies
WIREGUARD_IP="10.255.0.1"  # Default WireGuard IP
#
WAN_POLICY_IN="DROP"  # Default WAN input policy
WAN_POLICY_OUT="ACCEPT"  # Default WAN output policy
WAN_POLICY_FORWARD="DROP"  # Default WAN forward policy
#
OTHER_ZONES_POLICY_IN="DROP"  # Default input policy for other zones
OTHER_ZONES_POLICY_OUT="DROP"  # Default output policy for other zones
OTHER_ZONES_POLICY_FORWARD="DROP"  # Default forward policy for other zones
#
CORE_POLICY_IN="ACCEPT"  # Default Core input policy
CORE_POLICY_OUT="ACCEPT"  # Default Core output policy
CORE_POLICY_FORWARD="REJECT"  # Default Core forward policy

# Debugging: Log the default values
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

# Pass these values as environment variables to the scripts
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

# Export the variable to be used in other scripts
export ENABLE_WAN6

# Debugging: Log the exported variable
echo "Exported WAN6 enable option: $ENABLE_WAN6"

# Define SSIDs and their passphrases
SSID_OPENWRT="OpenWrt"
SSID_CLOSEDWRT="ClosedWrt"
SSID_IOTWRT="IoTWrt"
SSID_METAWRT="MetaWrt"

# Option to use pregenerated passphrases
USE_PREGENERATED_PASSPHRASES=true

# Option to use longer passphrases
PASSPHRASE_LENGTH=24  # Default length for passphrases

# Define the base directory of the script
BASE_DIR="$(cd "$(dirname "$0")" && pwd)"

# Export BASE_DIR to make it available to child scripts
export BASE_DIR

# Ensure the script runs from its own directory
cd "$BASE_DIR"

# Debugging: Log the current working directory
echo "Current working directory: $(pwd)"

# Debugging: Check if the maclist file exists and log its absolute path
MACLIST_PATH="$BASE_DIR/maclist"
if [ -f "$MACLIST_PATH" ]; then
  echo "Maclist file found at: $MACLIST_PATH"
  # Source the maclist file
  . "$MACLIST_PATH"
else
  echo "Error: Maclist file not found at $MACLIST_PATH. Please create a 'maclist' file."
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

# Debugging: Log the generated SSIDs and passphrases
echo "SSID: $SSID_OPENWRT, Passphrase: $PASSPHRASE_OPENWRT"
echo "SSID: $SSID_CLOSEDWRT, Passphrase: $PASSPHRASE_CLOSEDWRT"
echo "SSID: $SSID_IOTWRT, Passphrase: $PASSPHRASE_IOTWRT"
echo "SSID: $SSID_METAWRT, Passphrase: $PASSPHRASE_METAWRT"

# Export SSIDs and passphrases as environment variables
export SSID_OPENWRT
export SSID_CLOSEDWRT
export SSID_IOTWRT
export SSID_METAWRT
export PASSPHRASE_OPENWRT
export PASSPHRASE_CLOSEDWRT
export PASSPHRASE_IOTWRT
export PASSPHRASE_METAWRT

# Debugging: Log the exported variables
echo "Exported SSID and passphrase for OpenWrt: $SSID_OPENWRT / $PASSPHRASE_OPENWRT"
echo "Exported SSID and passphrase for ClosedWrt: $SSID_CLOSEDWRT / $PASSPHRASE_CLOSEDWRT"
echo "Exported SSID and passphrase for IoTWrt: $SSID_IOTWRT / $PASSPHRASE_IOTWRT"
echo "Exported SSID and passphrase for MetaWrt: $SSID_METAWRT / $PASSPHRASE_METAWRT"

# Debugging: Confirm script start
echo "install.sh script started a long time ago."

# Ensure the script is executed with root privileges
  if [ "$(id -u)" -ne 0 ]; then
    echo "Please run as root"
    exit 1
  fi

# Define the scripts directory using the absolute path from BASE_DIR
SCRIPTS_DIR="$BASE_DIR/scripts"

# Debugging: Log the resolved value of SCRIPTS_DIR
echo "Resolved SCRIPTS_DIR: $SCRIPTS_DIR"

# Check if the scripts directory exists
if [ ! -d "$SCRIPTS_DIR" ]; then
  echo "Scripts directory not found: $SCRIPTS_DIR"
  exit 1
fi

# Define log file
LOG_FILE="install_$(date +%Y%m%d_%H%M%S).log"
echo "Logging installation process to $LOG_FILE"

# Redirect stdout and stderr to both the terminal and the log file
exec > >(tee -a "$LOG_FILE") 2>&1

# Debugging: Log the start of the script
echo "Starting installation process..."

# Debugging: Log the scripts being processed
echo "Scripts directory: $SCRIPTS_DIR"
echo "Scripts to execute:"
ls -l "$SCRIPTS_DIR"/*.sh

# Debugging: Log the output of the ls command for matched scripts
echo "Files matched by glob pattern:"
ls "$SCRIPTS_DIR"/*.sh 2>/dev/null || echo "No files matched the glob pattern."

# Execute all scripts in the scripts directory
for script in "$SCRIPTS_DIR"/*.sh; do
  if [ -f "$script" ]; then
    chmod +x "$script"  # Ensure the script is executable
    # Adjusted logging for alignment
    echo "Running $script..."
    "$script"
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