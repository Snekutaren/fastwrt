#!/usr/bin/fish
# FastWrt Environment Initialization - Implementation using fish shell
# This script sets up the environment variables and common settings for FastWrt

# Source common color definitions
source "$PROFILE_DIR/colors.fish"

# Log the purpose of the script
print_start "Setting up FastWrt environment variables and defaults..."

# Create environment script in a writable location
set -gx FISH_ENV_SCRIPT "/tmp/fastwrt_env.fish"
print_info "Creating environment script at $FISH_ENV_SCRIPT"

# Generate the environment script with proper settings
# First create/clear the file
echo "" > $FISH_ENV_SCRIPT

# Then append all the content
begin
    echo '#!/usr/bin/fish'
    echo ''
    echo '# Set environment variables for FastWrt configuration'
    echo "set -gx BASE_DIR \"$BASE_DIR\""
    echo "set -gx CONFIG_DIR \"$CONFIG_DIR\""
    echo "set -gx PROFILES_DIR \"$PROFILES_DIR\""
    echo "set -gx PROFILE_DIR \"$PROFILE_DIR\"" 
    echo "set -gx DEFAULTS_DIR \"$DEFAULTS_DIR\""
    echo "set -gx CONFIG_PROFILE \"$CONFIG_PROFILE\""
    
    echo ''
    echo '# Pass through dry run mode and debug flags'
    echo 'if set -q DRY_RUN; and test "$DRY_RUN" = "true"'
    echo '  set -gx DRY_RUN true'
    echo '  echo "Environment: DRY RUN mode enabled"'
    echo 'else'
    echo '  set -gx DRY_RUN false'
    echo 'end'
    
    echo ''
    echo 'if set -q DEBUG; and test "$DEBUG" = "true"'
    echo '  set -gx DEBUG true'
    echo 'else'
    echo '  set -gx DEBUG false'
    echo 'end'
    
    echo ''
    echo '# Load network and security defaults'
    echo 'source "$PROFILE_DIR/defaults.fish" 2>/dev/null; or source "$BASE_DIR/config/defaults.fish" 2>/dev/null'
    
    echo ''
    echo '# Default network configuration values'
    # Fix the conditional block - echo the complete block rather than mixing echo with conditions
    echo 'if not set -q WIREGUARD_IP'
    echo '  set -gx WIREGUARD_IP "10.255.0.1"'
    echo 'end'
    
    echo 'if not set -q CORE_POLICY_IN'
    echo '  set -gx CORE_POLICY_IN "ACCEPT"'
    echo 'end'
    echo 'if not set -q CORE_POLICY_OUT'
    echo '  set -gx CORE_POLICY_OUT "ACCEPT"'
    echo 'end'
    echo 'if not set -q CORE_POLICY_FORWARD'
    echo '  set -gx CORE_POLICY_FORWARD "REJECT"'
    echo 'end'
    echo 'if not set -q OTHER_ZONES_POLICY_IN'
    echo '  set -gx OTHER_ZONES_POLICY_IN "REJECT"'  # Changed from DROP to REJECT
    echo 'end'
    echo 'if not set -q OTHER_ZONES_POLICY_OUT'
    echo '  set -gx OTHER_ZONES_POLICY_OUT "ACCEPT"'
    echo 'end'
    echo 'if not set -q IOT_META_POLICY_OUT'
    echo '  set -gx IOT_META_POLICY_OUT "DROP"'
    echo 'end'
    echo 'if not set -q OTHER_ZONES_POLICY_FORWARD'
    echo '  set -gx OTHER_ZONES_POLICY_FORWARD "REJECT"'
    echo 'end'
    echo 'if not set -q WAN_POLICY_IN'
    echo '  set -gx WAN_POLICY_IN "DROP"'
    echo 'end'
    echo 'if not set -q WAN_POLICY_OUT'
    echo '  set -gx WAN_POLICY_OUT "ACCEPT"'
    echo 'end'
    
    # CRITICAL FIX: Add a safety check to ensure WAN_POLICY_OUT is never set to DROP
    echo '# CRITICAL: Ensure WAN output policy is always ACCEPT to prevent internet loss'
    echo 'if test "$WAN_POLICY_OUT" = "DROP"'
    echo '  echo "$red""CRITICAL SAFETY FIX: WAN_POLICY_OUT was set to DROP, forcing to ACCEPT to prevent internet loss""$reset"'
    echo '  set -gx WAN_POLICY_OUT "ACCEPT"'
    echo 'end'
    
    echo ''
    echo '# IPv6 and feature flags'
    echo 'if not set -q ENABLE_WAN6'
    echo '  set -gx ENABLE_WAN6 false'
    echo 'end'
    echo 'if not set -q ENABLE_MAC_FILTERING'
    echo '  set -gx ENABLE_MAC_FILTERING true'
    echo 'end'
    echo 'if not set -q WIFI_MAC_FILTERING'
    echo '  set -gx WIFI_MAC_FILTERING "allow"'
    echo 'end'
    
    echo ''
    echo '# Default SSIDs'
    echo 'if not set -q SSID_CLOSEDWRT'
    echo '  set -gx SSID_CLOSEDWRT "ClosedWrt"'
    echo 'end'
    echo 'if not set -q SSID_OPENWRT'
    echo '  set -gx SSID_OPENWRT "OpenWrt"'
    echo 'end'
    echo 'if not set -q SSID_METAWRT'
    echo '  set -gx SSID_METAWRT "MetaWrt"'
    echo 'end'
    echo 'if not set -q SSID_IOTWRT'
    echo '  set -gx SSID_IOTWRT "IoTWrt"'
    echo 'end'
    
    echo ''
    echo '# Print security notice about environment'
    echo 'print_security "Environment variables set. These control critical security settings."'
end >> $FISH_ENV_SCRIPT

chmod +x $FISH_ENV_SCRIPT
print_success "Environment script created successfully"

# Source the environment script to apply the settings in the current script
source $FISH_ENV_SCRIPT

# Security notice using the new orange color
print_security "Environment configuration contains sensitive security settings. Review carefully."

# Done
print_success "Environment initialization completed."
