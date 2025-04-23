#!/usr/bin/fish
# FastWrt WireGuard configuration script - Implementation using fish shell
# Fish shell is the default shell in FastWrt and should be used for all scripts

# Set colors for better readability
set green (echo -e "\033[0;32m")
set yellow (echo -e "\033[0;33m")
set red (echo -e "\033[0;31m")
set blue (echo -e "\033[0;34m")
set purple (echo -e "\033[0;35m")
set reset (echo -e "\033[0m")

# Ensure the script runs from its own directory
cd $BASE_DIR
echo "$blue""Current working directory: ""$reset"(pwd)

# Log the start of the script
echo "$purple""Starting WireGuard configuration...""$reset"

# First confirm the wireguard interface exists in network configuration
echo "$blue""Verifying WireGuard network interface...""$reset"
if not uci -q get network.wireguard > /dev/null
    echo "$red""ERROR: WireGuard network interface (network.wireguard) not found.""$reset"
    echo "$yellow""Make sure 30-network.sh has run successfully first.""$reset"
    exit 1
end

# Generate WireGuard keys if they don't exist
echo "$blue""Setting up WireGuard keys...""$reset"
set WG_KEY_DIR "/etc/wireguard"
mkdir -p "$WG_KEY_DIR"
chmod 700 "$WG_KEY_DIR"

# Generate server keys if they don't exist
set SERVER_PRIVATE_KEY_FILE "$WG_KEY_DIR/server_private.key"
set SERVER_PUBLIC_KEY_FILE "$WG_KEY_DIR/server_public.key"

if not test -f "$SERVER_PRIVATE_KEY_FILE"
    echo "$yellow""Generating WireGuard server keys...""$reset"
    wg genkey | tee "$SERVER_PRIVATE_KEY_FILE" | wg pubkey > "$SERVER_PUBLIC_KEY_FILE"
    chmod 600 "$SERVER_PRIVATE_KEY_FILE" "$SERVER_PUBLIC_KEY_FILE"
    echo "$green""Server keys generated successfully""$reset"
else
    echo "$yellow""Using existing WireGuard server keys""$reset"
end

# Read keys
set SERVER_PRIVATE_KEY (cat "$SERVER_PRIVATE_KEY_FILE")
set SERVER_PUBLIC_KEY (cat "$SERVER_PUBLIC_KEY_FILE")

echo "$blue""Server public key: ""$reset"
if test "$DEBUG" = "true"
    echo "$SERVER_PUBLIC_KEY"
else
    echo "(hidden - run with --debug to reveal)"
end

# Configure WireGuard interface directly (don't create separate section)
echo "$blue""Configuring WireGuard interface parameters...""$reset"

# Set keys and parameters directly on the wireguard interface, not a separate wg_server section
uci set network.wireguard.private_key="$SERVER_PRIVATE_KEY" 
uci set network.wireguard.listen_port='52018'
# Use proper CIDR notation for the address
uci set network.wireguard.addresses="$WIREGUARD_IP/24"

# Create a few example client peers
echo "$blue""Setting up example client peers...""$reset"

# Function to add a peer with proper section naming
function add_wireguard_peer
    set name $argv[1]
    set public_key $argv[2]
    set allowed_ips $argv[3]
    set endpoint $argv[4]  # Optional
    
    echo "$yellow""Adding peer: $name""$reset"
    
    # Create a section named 'peer_$name' for better organization
    set section_name "peer_$name"
    uci set network.$section_name='wireguard_peer'  # Changed from 'wireguard_wireguard_peer'
    uci set network.$section_name.public_key="$public_key"
    uci set network.$section_name.allowed_ips="$allowed_ips"
    uci set network.$section_name.description="$name"
    
    # Only set endpoint if provided
    if test -n "$endpoint"
        uci set network.$section_name.endpoint="$endpoint"
        uci set network.$section_name.persistent_keepalive='25'
    end
    
    # Route allowed IPs
    uci set network.$section_name.route_allowed_ips='1'
end

# Add example client (keys would normally be generated on the client side)
# Note: In production, generate actual keys for each client

# Example client key generation (commented out - for reference only)
# set CLIENT_PRIVATE_KEY (wg genkey)
# set CLIENT_PUBLIC_KEY (echo $CLIENT_PRIVATE_KEY | wg pubkey)

# Example hardcoded public key (NOT FOR PRODUCTION USE)
set EXAMPLE_CLIENT_PUBLIC_KEY "4H/Bhi5RevX5Rw5vQdE+MyDEDEXAMPLEPUBKEY1234567890="

# Add client as peer - this would be done for each client device
add_wireguard_peer "client1" "$EXAMPLE_CLIENT_PUBLIC_KEY" "10.255.0.2/32"

# Set WireGuard DNS settings to use the VPN server as DNS
echo "$blue""Configuring WireGuard to use internal DNS...""$reset"
uci set network.wireguard.dns="$WIREGUARD_IP"
echo "$green""DNS set to $WIREGUARD_IP for increased security""$reset"

# Add recovery mechanism for cases where WireGuard doesn't configure properly
echo "$blue""Adding secondary WireGuard recovery script...""$reset"

# Create repair script using fish-compatible method instead of heredoc
set repair_script "/usr/bin/repair-wireguard"
echo '#!/bin/sh' > $repair_script
echo '# WireGuard repair script for FastWrt' >> $repair_script
echo '' >> $repair_script
echo '# Check if WireGuard interface exists' >> $repair_script
echo 'if ! ip link show wireguard >/dev/null 2>&1; then' >> $repair_script
echo '  echo "WireGuard interface not found. Attempting repair..."' >> $repair_script
echo '  ' >> $repair_script
echo '  # Try to manually bring up the interface using wg-quick equivalent commands' >> $repair_script
echo '  ip link add dev wireguard type wireguard' >> $repair_script
echo '  ' >> $repair_script
echo '  # Get needed values from UCI' >> $repair_script
echo '  PRIVATE_KEY=$(uci -q get network.wireguard.private_key)' >> $repair_script
echo '  LISTEN_PORT=$(uci -q get network.wireguard.listen_port)' >> $repair_script
echo '  WG_ADDRESS=$(uci -q get network.wireguard.addresses | cut -d "/" -f1)' >> $repair_script
echo '  WG_NETMASK=$(uci -q get network.wireguard.addresses | cut -d "/" -f2)' >> $repair_script
echo '  ' >> $repair_script
echo '  # Set interface configuration' >> $repair_script
echo '  [ -n "$PRIVATE_KEY" ] && wg set wireguard private-key <(echo "$PRIVATE_KEY")' >> $repair_script
echo '  [ -n "$LISTEN_PORT" ] && wg set wireguard listen-port "$LISTEN_PORT"' >> $repair_script
echo '  ' >> $repair_script
echo '  # Set IP address' >> $repair_script
echo '  if [ -n "$WG_ADDRESS"]; then' >> $repair_script
echo '    if [ -z "$WG_NETMASK"]; then' >> $repair_script
echo '      WG_NETMASK="24"  # Default netmask if missing' >> $repair_script
echo '    fi' >> $repair_script
echo '    ip addr add "${WG_ADDRESS}/${WG_NETMASK}" dev wireguard' >> $repair_script
echo '  fi' >> $repair_script
echo '  ' >> $repair_script
echo '  # Bring interface up' >> $repair_script
echo '  ip link set wireguard up' >> $repair_script
echo '  ' >> $repair_script
echo '  # Add each peer' >> $repair_script
echo '  for PEER_SECTION in $(uci show network | grep wireguard_peer | cut -d. -f2 | cut -d= -f1 | sort -u); do' >> $repair_script
echo '    PUBLIC_KEY=$(uci -q get network.$PEER_SECTION.public_key)' >> $repair_script
echo '    ALLOWED_IPS=$(uci -q get network.$PEER_SECTION.allowed_ips)' >> $repair_script
echo '    ENDPOINT=$(uci -q get network.$PEER_SECTION.endpoint)' >> $repair_script
echo '    PERSISTENT_KEEPALIVE=$(uci -q get network.$PEER_SECTION.persistent_keepalive)' >> $repair_script
echo '    ' >> $repair_script
echo '    if [ -n "$PUBLIC_KEY"] && [ -n "$ALLOWED_IPS"]; then' >> $repair_script
echo '      PEER_CMD="wg set wireguard peer $PUBLIC_KEY allowed-ips $ALLOWED_IPS"' >> $repair_script
echo '      [ -n "$ENDPOINT"] && PEER_CMD="$PEER_CMD endpoint $ENDPOINT"' >> $repair_script
echo '      [ -n "$PERSISTENT_KEEPALIVE"] && PEER_CMD="$PEER_CMD persistent-keepalive $PERSISTENT_KEEPALIVE"' >> $repair_script
echo '      ' >> $repair_script
echo '      eval "$PEER_CMD"' >> $repair_script
echo '    fi' >> $repair_script
echo '  done' >> $repair_script
echo '  ' >> $repair_script
echo '  echo "WireGuard repair attempted. Checking interface..."' >> $repair_script
echo '  sleep 2' >> $repair_script
echo '  if ip link show wireguard >/dev/null 2>&1; then' >> $repair_script
echo '    echo "WireGuard interface now available!"' >> $repair_script
echo '    echo "Configuration:"' >> $repair_script
echo '    wg show wireguard' >> $repair_script
echo '  else' >> $repair_script
echo '    echo "WireGuard repair failed. You may need to reboot the device."' >> $repair_script
echo '  fi' >> $repair_script
echo 'else' >> $repair_script
echo '  echo "WireGuard interface exists and appears to be working."' >> $repair_script
echo '  echo "Configuration:"' >> $repair_script
echo '  wg show wireguard' >> $repair_script
echo 'fi' >> $repair_script

# Make the repair script executable
chmod +x $repair_script
echo "$green""Created recovery script at $repair_script""$reset"
echo "$yellow""If WireGuard doesn't work after installation, run: repair-wireguard""$reset"

# Add to cronjob to check at reboot to ensure WireGuard interface is created
# This will run the repair script once at boot if needed
echo "$blue""Adding WireGuard check to cron jobs...""$reset"
mkdir -p /etc/crontabs
if ! grep -q "repair-wireguard" /etc/crontabs/root 2>/dev/null
    echo "@reboot sleep 60 && ip link show wireguard >/dev/null 2>&1 || /usr/bin/repair-wireguard" >> /etc/crontabs/root
    echo "$green""Added WireGuard check to cron jobs""$reset"
end  # Added missing end statement here

# Verify configuration
echo "$blue""Verifying WireGuard configuration...""$reset"
uci show network | grep wireguard

# Add status message about client configuration
echo "$yellow""
WireGuard Client Configuration Info:
-----------------------------------
Server Public Key: $SERVER_PUBLIC_KEY
Server Endpoint: <YOUR_PUBLIC_IP>:52018
Allowed IPs: 0.0.0.0/0  # Route all traffic through VPN
Client IP: 10.255.0.2/32

To configure clients:
1. Generate client keys with: wg genkey | tee client_private.key | wg pubkey > client_public.key
2. Add the client public key to the server (in this script)
3. Set up client with server public key and endpoint
""$reset"

# Setup complete
echo "$green""WireGuard configuration completed successfully.""$reset"
echo "$yellow""Note: Remember to enable the WAN port forwarding rule to access WireGuard from outside.""$reset"

# Add verification note - but don't try to verify now since commits happen later
echo "$blue""WireGuard interface will be verified after network restart.""$reset"
echo "$yellow""If the WireGuard interface doesn't appear after installation, you may need to reboot the device.""$reset"

# Note: UCI commits are handled by the parent script
echo "$green""WireGuard configuration changes complete. Changes will be applied during final commit.""$reset"
