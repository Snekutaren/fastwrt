#!/usr/bin/fish
# FastWrt WireGuard configuration script - Implementation using fish shell

# Source common color definitions
source "$PROFILE_DIR/colors.fish"

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

# Clean up existing WireGuard configuration to ensure idempotency
echo "$blue""Cleaning up existing WireGuard configuration...""$reset"

# 1. Remove all existing WireGuard peers
set wg_peer_count 0
while true
    # Find sections with 'wireguard_peer' type
    set peer_sections (uci show network | grep "=wireguard_peer" | cut -d'=' -f1)
    
    # Break if no more peer sections found
    if test -z "$peer_sections"
        break
    end
    
    # Remove each peer section
    for section in $peer_sections
        echo "$yellow""Removing existing WireGuard peer: $section""$reset"
        uci delete $section 2>/dev/null
        or echo "$yellow""Note: $section already removed or not found""$reset"
        set wg_peer_count (math $wg_peer_count + 1)
    end
end

# 2. Remove any anonymous wireguard sections
set anon_count 0
while true
    # Look for anonymous wireguard sections
    set anon_sections (uci show network | grep "=wireguard" | cut -d'=' -f1)
    
    # Break if no more sections found
    if test -z "$anon_sections"
        break
    end
    
    # Remove each section
    for section in $anon_sections
        echo "$yellow""Removing existing WireGuard section: $section""$reset"
        uci delete $section 2>/dev/null
        or echo "$yellow""Note: $section already removed or not found""$reset"
        set anon_count (math $anon_count + 1)
    end
end

# Summarize cleanup
if test $wg_peer_count -gt 0 -o $anon_count -gt 0
    echo "$green""Cleaned up $wg_peer_count WireGuard peers and $anon_count anonymous WireGuard sections""$reset"
else
    echo "$green""No existing WireGuard configuration to clean up""$reset"
end

# Load external key file from multiple potential locations
set WG_KEYS_FILES "$PROFILE_DIR/wgkeys.fish" "$DEFAULTS_DIR/wgkeys.fish" "$CONFIG_DIR/wgkeys.fish" "$BASE_DIR/wgkeys.fish"
set WG_KEYS_FILE ""

for file_path in $WG_KEYS_FILES
    if test -f "$file_path"
        set WG_KEYS_FILE "$file_path"
        echo "$green""Loading WireGuard keys from: $WG_KEYS_FILE""$reset"
        source "$WG_KEYS_FILE"
        echo "$green""WireGuard keys loaded successfully""$reset"
        break
    end
end

if test -z "$WG_KEYS_FILE"
    echo "$red""ERROR: WireGuard keys file not found. Please create a 'wgkeys.fish' file in one of these locations:""$reset"
    for path in $WG_KEYS_FILES
        echo "$red""- $path""$reset"
    end
    echo "$red""The file should contain private and public keys for both server and clients.""$reset"
    echo "$red""Example format:
    set -gx WG_SERVER_PRIVATE_KEY \"private_key_value\"
    set -gx WG_SERVER_PUBLIC_KEY \"public_key_value\"
    set -gx WG_CLIENT_KEY_NAME \"client_public_key_value\"
    set -gx WG_CLIENT_IP_NAME \"client_ip_address\"""$reset"
    exit 1
end

# Check if required server keys exist in environment
if not set -q WG_SERVER_PRIVATE_KEY; or not set -q WG_SERVER_PUBLIC_KEY
    echo "$red""ERROR: WireGuard server keys not found in $WG_KEYS_FILE.""$reset"
    echo "$red""Please ensure WG_SERVER_PRIVATE_KEY and WG_SERVER_PUBLIC_KEY are defined.""$reset"
    echo "$red""You can generate these keys using the 'wg' command line tool:""$reset"
    echo "$yellow""  wg genkey | tee server_private.key | wg pubkey > server_public.key""$reset"
    exit 1
end

# Mask keys in normal output, show only in debug mode
if test "$DEBUG" = "true"
    echo "$blue""Server public key: ""$reset"$WG_SERVER_PUBLIC_KEY
else
    echo "$blue""Server public key: ""$reset""[MASKED - use --debug to display]"
end

# Configure WireGuard interface directly
echo "$blue""Configuring WireGuard interface parameters...""$reset"

# Ensure WireGuard IP is properly defined
if test -z "$WIREGUARD_IP"
    echo "$yellow""WIREGUARD_IP is not set! Using default 10.255.0.1""$reset"
    set WIREGUARD_IP "10.255.0.1"
end

# Ensure WireGuard IP is in CIDR notation
set WIREGUARD_IP_CIDR "$WIREGUARD_IP/24"
# Extract the address without the CIDR for DNS
set WIREGUARD_IP_ONLY (echo $WIREGUARD_IP | cut -d'/' -f1)

# Configure the interface
echo "$blue""Setting WireGuard IP address to $WIREGUARD_IP_CIDR""$reset"
uci set network.wireguard='interface'
uci set network.wireguard.proto='wireguard'
uci set network.wireguard.private_key="$WG_SERVER_PRIVATE_KEY" 
uci set network.wireguard.listen_port='52018'
uci set network.wireguard.addresses="$WIREGUARD_IP_CIDR"
uci set network.wireguard.force_link='1'  # Ensure interface stays up

# Critical: Add correct route handling
uci set network.wireguard.route_allowed_ips='1' # Ensure routes to allowed IPs are installed

# Define peer creation function with proper UCI format
function add_wireguard_peer
    set name $argv[1]
    set public_key $argv[2]
    set client_ip $argv[3]
    
    echo "$yellow""Adding peer: $name (IP: $client_ip)""$reset"
    
    # First create the named peer section with uppercase name as seen in UCI output
    set uppercase_name (string upper $name)
    set section_name "peer_$uppercase_name"
    
    # Create main peer entry
    uci set network.$section_name='wireguard_peer'
    uci set network.$section_name.public_key="$public_key"
    uci set network.$section_name.interface='wireguard'
    # CRITICAL FIX: Format allowed_ips as a list with individual entries for better compatibility
    uci delete network.$section_name.allowed_ips 2>/dev/null
    uci add_list network.$section_name.allowed_ips="$client_ip/32"
    uci add_list network.$section_name.allowed_ips="0.0.0.0/0"
    uci set network.$section_name.description="$name"
    
    # Apply the persistent keepalive setting to ensure mobile connections stay active
    uci set network.$section_name.persistent_keepalive='25'
    echo "$yellow""Set persistent keepalive to 25 seconds to maintain mobile connections""$reset"

    uci set network.$section_name.route_allowed_ips='1'
    
    # Add corresponding anonymous wireguard_wireguard section as seen in UCI output
    uci add network wireguard_wireguard
    uci set network.@wireguard_wireguard[-1].public_key="$public_key"
    uci set network.@wireguard_wireguard[-1].description="$name"
    uci set network.@wireguard_wireguard[-1].allowed_ips="$client_ip/32,0.0.0.0/0"
    
    # Verify the peer was added properly
    if not uci -q get network.$section_name > /dev/null
        echo "$red""ERROR: Failed to create WireGuard peer $name!""$reset"
        return 1
    end
    
    echo "$green""Successfully configured WireGuard peer: $name""$reset"
    return 0
end

# Function to count actual configured peers properly using UCI
function count_wireguard_peers
    # Count both named wireguard_peer sections and anonymous wireguard_wireguard sections
    set named_peers (uci show network | grep "=wireguard_peer" | wc -l || echo 0)
    set anon_peers (uci show network | grep "@wireguard_wireguard" | wc -l || echo 0)
    
    # Return the count of named peers as that's what should match our added peers
    echo $named_peers
end

# Configure client peers with dynamic discovery
echo "$blue""Setting up WireGuard client peers...""$reset"

# Debug output to check if keys are loaded
if test "$DEBUG" = "true"
    echo "$yellow""DEBUG: Available WireGuard client variables:""$reset"
    set | grep -E "WG_CLIENT_(KEY|IP)_" | sort
end

# Initialize peer counter for tracking but don't store in UCI
set peer_count 0

# Directly check for the specific client keys and IPs we expect
if set -q WG_CLIENT_KEY_S10; and set -q WG_CLIENT_IP_S10
    echo "$blue""Adding client peer: S10 with IP $WG_CLIENT_IP_S10""$reset"
    if add_wireguard_peer "s10" "$WG_CLIENT_KEY_S10" "$WG_CLIENT_IP_S10"
        set peer_count (math $peer_count + 1)
    end
else
    echo "$yellow""Skipping S10 peer - missing key or IP""$reset"
    # Debug without exposing keys
    if test "$DEBUG" = "true"
        echo "$yellow""DEBUG: WG_CLIENT_KEY_S10 exists: ""$reset"(set -q WG_CLIENT_KEY_S10)
        echo "$yellow""DEBUG: WG_CLIENT_IP_S10 exists: ""$reset"(set -q WG_CLIENT_IP_S10)
    end
end

if set -q WG_CLIENT_KEY_ROG; and set -q WG_CLIENT_IP_ROG
    echo "$blue""Adding client peer: ROG with IP $WG_CLIENT_IP_ROG""$reset"
    if add_wireguard_peer "rog" "$WG_CLIENT_KEY_ROG" "$WG_CLIENT_IP_ROG"
        set peer_count (math $peer_count + 1)
    end
else
    echo "$yellow""Skipping ROG peer - missing key or IP""$reset"
    # Debug without exposing keys
    if test "$DEBUG" = "true"
        echo "$yellow""DEBUG: WG_CLIENT_KEY_ROG exists: ""$reset"(set -q WG_CLIENT_KEY_ROG)
        echo "$yellow""DEBUG: WG_CLIENT_IP_ROG exists: ""$reset"(set -q WG_CLIENT_IP_ROG)
    end
end

# Summary of peer creation using the count from the function
set actual_peers (count_wireguard_peers)
echo "$green""Successfully added $peer_count WireGuard peers (UCI shows $actual_peers configured)""$reset"

# Remove direct iptables commands and use UCI configuration instead
echo "$blue""Ensuring proper firewall masquerading for WireGuard traffic...""$reset"

# Extract the WireGuard subnet for the firewall rules reference
set wg_subnet "10.255.0.0/24"  # Default value
set wg_addr (uci -q get network.wireguard.addresses | cut -d'/' -f1)
if test -n "$wg_addr"
    set wg_subnet (echo "$wg_addr" | sed -E 's/\.[0-9]+$/.0\/24/')
end

# Display information about the subnet for clarity
echo "$green""WireGuard subnet: $wg_subnet will be masqueraded through the firewall configuration""$reset"
echo "$yellow""Masquerading is configured through UCI in the firewall script (50-firewall.sh)""$reset"

# Set WireGuard DNS settings
if test -n "$WIREGUARD_IP_ONLY" 
    uci set network.wireguard.dns="$WIREGUARD_IP_ONLY"
    echo "$green""DNS set to $WIREGUARD_IP_ONLY for increased security""$reset"
else
    echo "$red""ERROR: Could not set WireGuard DNS - WIREGUARD_IP is not properly defined""$reset"
end

# Verify configuration
echo "$blue""Verifying WireGuard configuration...""$reset"
echo "$green""WireGuard interface configured""$reset"
echo "$blue""- Interface: ""$reset""wireguard"
echo "$blue""- IP address: ""$reset""$WIREGUARD_IP_CIDR"
echo "$blue""- Port: ""$reset""52018"
echo "$blue""- Peers: ""$reset"(count_wireguard_peers)

# Note: UCI commits are handled by the parent script
echo "$green""WireGuard configuration changes complete. Changes will be applied during final commit.""$reset"

# Enhanced mobile connectivity document reference
echo "$blue""For mobile connectivity issues, see docs/WIREGUARD-CONNECTION.md""$reset"
echo "$green""Use direct IP address (ssh root@$WIREGUARD_IP -p 6622) when connecting through mobile networks""$reset"
