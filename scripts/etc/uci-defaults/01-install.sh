#!/usr/bin/fish

# filepath: c:\Users\win11\Documents\FastWrt\Firmware\scripts\etc\uci-defaults\01-install.sh

# Start
echo "FastWrt Configuration Running from: "(cd (dirname (status filename)) && pwd)
echo "Current time: "(date)

# Default configuration
set DEBUG_MODE false
set DRY_RUN false

# Parse command line arguments
for arg in $argv
    switch $arg
        case "--debug"
            set DEBUG_MODE true
            echo "Debug mode enabled"
            set -gx DEBUG true
        case "--dry-run"
            set DRY_RUN true
            echo "Dry run mode enabled - no changes will be committed"
            set -gx DRY_RUN true
    end
end

# Log file
set LOG_FILE "install_"(date +%Y%m%d_%H%M%S)".log"
echo "Logging installation process to $LOG_FILE"

# Check for root privileges
if test (id -u) -ne 0
    echo "Please run as root"
    exit 1
end

# Base directory
set BASE_DIR (cd (dirname (status filename)) && pwd)
set -gx BASE_DIR $BASE_DIR
set CURRENT_SCRIPT (realpath (status filename))

# Create env.fish
set FISH_ENV_SCRIPT "$BASE_DIR/env.fish"
begin
    echo '#!/usr/bin/fish'
    echo ''
    echo '# Set environment variables for the configuration'
    echo "set -gx BASE_DIR \"$BASE_DIR\""
    echo ''
    echo '# Pass through dry run mode and debug flags if set'
    echo 'if test "$DRY_RUN" = "true"'
    echo '  set -gx DRY_RUN true'
    echo '  echo "Fish environment: DRY RUN mode enabled"'
    echo 'else'
    echo '  set -gx DRY_RUN false'
    echo 'end'
    echo ''
    echo 'if test "$DEBUG" = "true"'
    echo '  set -gx DEBUG true'
    echo 'else'
    echo '  set -gx DEBUG false'
    echo 'end'
    echo ''
    echo '# Default configuration values'
    echo 'set -gx WIREGUARD_IP "10.255.0.1"'
    echo 'set -gx CORE_POLICY_IN "ACCEPT"'
    echo 'set -gx CORE_POLICY_OUT "ACCEPT"'
    echo 'set -gx CORE_POLICY_FORWARD "REJECT"'
    echo 'set -gx OTHER_ZONES_POLICY_IN "DROP"'
    echo 'set -gx OTHER_ZONES_POLICY_OUT "DROP"'
    echo 'set -gx OTHER_ZONES_POLICY_FORWARD "DROP"'
    echo 'set -gx WAN_POLICY_IN "DROP"'
    echo 'set -gx WAN_POLICY_OUT "ACCEPT"'
    echo 'set -gx WAN_POLICY_FORWARD "DROP"'
    echo ''
    echo '# Option to enable WAN6'
    echo 'set -gx ENABLE_WAN6 false'
    echo ''
    echo '# Option to enable MAC filtering'
    echo 'set -gx ENABLE_MAC_FILTERING true'
    echo ''
    echo '# SSIDs'
    echo 'set -gx SSID_CLOSEDWRT "ClosedWrt"'
    echo 'set -gx SSID_OPENWRT "OpenWrt"'
    echo 'set -gx SSID_METAWRT "MetaWrt"'
    echo 'set -gx SSID_IOTWRT "IoTWrt"'
    echo ''
    echo '# Print environment variables only once'
    echo 'if status --is-interactive; and not set -q ENVIRONMENT_PRINTED'
    echo '  set -gx ENVIRONMENT_PRINTED 1'
    echo '  echo "Configuration environment set up."'
    echo '  echo "BASE_DIR: $BASE_DIR"'
    echo '  echo "DRY_RUN: $DRY_RUN"'
    echo '  echo "DEBUG: $DEBUG"'
    echo '  echo "Core policies: $CORE_POLICY_IN/$CORE_POLICY_OUT/$CORE_POLICY_FORWARD"'
    echo '  echo "WAN policies: $WAN_POLICY_IN/$WAN_POLICY_OUT/$WAN_POLICY_FORWARD"'
    echo '  echo "ENABLE_WAN6: $ENABLE_WAN6"'
    echo '  echo "ENABLE_MAC_FILTERING: $ENABLE_MAC_FILTERING"'
    echo '  echo "SSIDs: $SSID_OPENWRT, $SSID_CLOSEDWRT, $SSID_METAWRT, $SSID_IOTWRT"'
    echo 'end'
end > $FISH_ENV_SCRIPT

# Passphrase and MAC list
set USE_PREGENERATED_PASSPHRASES true
set PASSPHRASE_LENGTH 32
echo "Using pregenerated passphrases: $USE_PREGENERATED_PASSPHRASES"
echo "Passphrase length: $PASSPHRASE_LENGTH"

set MACLIST_PATH "$BASE_DIR/maclist.csv"
if test -f "$MACLIST_PATH"
    echo "Maclist file found at: $MACLIST_PATH"
else
    echo "Error: Maclist file not found at $MACLIST_PATH. Please create a 'maclist.csv' file."
    exit 1
end

if test "$USE_PREGENERATED_PASSPHRASES" = "true"
    echo "Checking for fish-compatible passphrases file in $BASE_DIR..."
    if test -f "$BASE_DIR/passphrases.fish"
        echo "Fish-compatible passphrases file found at: $BASE_DIR/passphrases.fish"
    else
        echo "Error: Fish-compatible passphrases file not found in $BASE_DIR. Please create a 'passphrases.fish' file."
        exit 1
    end
else
    echo "# Generating random passphrases" >> "$FISH_ENV_SCRIPT"
    echo "set -gx PASSPHRASE_OPENWRT \""(openssl rand -base64 $PASSPHRASE_LENGTH)"\"" >> "$FISH_ENV_SCRIPT"
    echo "set -gx PASSPHRASE_CLOSEDWRT \""(openssl rand -base64 $PASSPHRASE_LENGTH)"\"" >> "$FISH_ENV_SCRIPT"
    echo "set -gx PASSPHRASE_IOTWRT \""(openssl rand -base64 $PASSPHRASE_LENGTH)"\"" >> "$FISH_ENV_SCRIPT"
    echo "set -gx PASSPHRASE_METAWRT \""(openssl rand -base64 $PASSPHRASE_LENGTH)"\"" >> "$FISH_ENV_SCRIPT"
end

echo "Generated fish environment script contents:"
cat "$FISH_ENV_SCRIPT"

# Execute all .sh scripts in the directory, skipping itself
set SCRIPTS_DIR "$BASE_DIR"
if test ! -d "$SCRIPTS_DIR"
    echo "Scripts directory not found: $SCRIPTS_DIR"
    exit 1
end
echo "Scripts directory: $SCRIPTS_DIR"
echo "Scripts to execute:"
ls -l "$SCRIPTS_DIR"/*.sh

echo "Executing configuration scripts with fish shell..."
for script in "$SCRIPTS_DIR"/*.sh
    if test (realpath "$script") = $CURRENT_SCRIPT
        echo "Skipping self: $script"
        continue
    end
    echo "Running $script"
    fish -C "source $FISH_ENV_SCRIPT" "$script"
end

echo "All scripts executed. Installation complete."
echo "Installation process completed. Log saved to $LOG_FILE"

# If dry-run is enabled, show UCI changes instead of executing scripts
if test "$DRY_RUN" = "true"
    echo "--- DRY RUN: Displaying detected UCI configuration changes ---"
    set modified_configs (uci changes | cut -d. -f1 | cut -d: -f1 | sort -u)
    if test (count $modified_configs) -eq 0
        echo "No UCI changes detected."
    else
        for cfg in $modified_configs
            echo "Changes in: $cfg"
            uci changes $cfg
        end
    end
    echo "--- END OF UCI CHANGES ---"
    
    for cfg in (uci show | cut -d. -f1 | cut -d: -f1 | sort | uniq)
    echo "Reverting $cfg..."
    uci revert $cfg
    end

    echo "Exiting due to dry run mode."
    rm -f "$FISH_ENV_SCRIPT"
    exit 0
end

# Finalize configuration if not a dry run
echo "Committing UCI changes..."
uci commit

echo "Restarting services to apply changes..."
/etc/init.d/firewall reload
/etc/init.d/dnsmasq reload
/etc/init.d/dropbear restart
/etc/init.d/network restart

echo "All services restarted. You may need to reconnect if network settings changed."
