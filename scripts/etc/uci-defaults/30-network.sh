#!/usr/bin/fish
# FastWrt network configuration - Implementation using fish shell
# Fish shell is the default shell in FastWrt and should be used for all scripts

# Source common color definitions
source "$PROFILE_DIR/colors.fish"

# Ensure the script runs from its own directory
cd $BASE_DIR
echo "$blue""Current working directory: ""$reset"(pwd)

# Log the start of the script
echo "$green""Starting network configuration...""$reset"

### --- Network Configuration ---
# Clean up existing configs (using idempotent approach)
echo "$blue""Cleaning up existing network configurations...""$reset"

# First check which network interfaces actually exist
set existing_interfaces
for config in lan_dev wan_dev br-lan br-wan lan
    if uci -q get network.$config > /dev/null 2>&1
        set -a existing_interfaces $config
    end
end

if test (count $existing_interfaces) -gt 0
    echo "$yellow""Found ""$reset"(count $existing_interfaces)"$yellow"" existing network interfaces to clean up""$reset"
    
    # Now delete only the interfaces that actually exist
    for config in $existing_interfaces
        echo "$yellow""Deleting network.$config...""$reset"
        uci delete network.$config
        echo "$green""Deleted network.$config successfully""$reset"
    end
else
    echo "$green""No existing network interfaces found that need cleanup""$reset"
end

echo "$green""Network configuration cleanup completed.""$reset"

# Clean up orphaned device entries (also idempotently)
echo "$blue""Checking for orphaned device entries...""$reset"
set orphaned_devices
for device in (uci show network 2>/dev/null | grep -E '@device\[[0-9]+\]' | cut -d. -f2 | cut -d= -f1)
    set -a orphaned_devices $device
end

if test (count $orphaned_devices) -gt 0
    echo "$yellow""Found ""$reset"(count $orphaned_devices)"$yellow"" orphaned device entries to clean up""$reset"
    
    # Delete each orphaned device
    for device in $orphaned_devices
        echo "$yellow""Deleting network.$device...""$reset"
        uci delete network."$device"
        echo "$green""Deleted network.$device successfully""$reset"
    end
else
    echo "$green""No orphaned device entries found""$reset"
end

echo "$green""Orphaned device cleanup completed.""$reset"

# Loopback (only if not already defined) - idempotent approach
echo "$blue""Configuring loopback interface...""$reset"
if not uci -q get network.loopback > /dev/null
  echo "$yellow""Creating loopback interface configuration...""$reset"
  uci set network.loopback='interface'
  uci set network.loopback.device='lo'
  uci set network.loopback.proto='static'
  uci set network.loopback.ipaddr='127.0.0.1'
  uci set network.loopback.netmask='255.0.0.0'
  echo "$green""Loopback interface configured successfully.""$reset"
else
  echo "$green""Loopback interface already exists, no changes needed.""$reset"
end

# Global settings - idempotent approach
echo "$blue""Configuring global network settings...""$reset"
uci set network.globals='globals'
uci set network.globals.ula_prefix='fdd7:1414:1d85::/48'
uci set network.globals.packet_steering='1'
echo "$green""Global network settings configured successfully.""$reset"

# LAN Bridge (br-lan) - idempotent approach
echo "$blue""Configuring LAN bridge (br-lan)...""$reset"
uci set network.lan_dev='device'
uci set network.lan_dev.name='br-lan'
uci set network.lan_dev.type='bridge'

# First check if ports are already configured
set current_ports (uci -q get network.lan_dev.ports 2>/dev/null | string split " ")
if test (count $current_ports) -gt 0
  # Only show detailed port info in debug mode
  if test "$DEBUG" = "true"
    echo "$yellow""Existing LAN ports found: ""$reset"(string join ", " $current_ports)
  else
    echo "$yellow""Reconfiguring existing LAN ports""$reset"
  end
  uci delete network.lan_dev.ports
  echo "$green""Cleaned up existing LAN bridge ports.""$reset"
end

# Adding ports with proper logging
set required_ports "eth1" "lan1" "lan3" "lan4" "lan5"
# Only log individual port adds in debug mode
if test "$DEBUG" = "true"
  for port in $required_ports
    echo "$blue""Adding port $port to LAN bridge...""$reset"
    uci add_list network.lan_dev.ports="$port"
  end
else
  # Simple summary in normal mode
  echo "$blue""Adding ""$reset"(count $required_ports)"$blue"" ports to LAN bridge...""$reset"
  for port in $required_ports
    uci add_list network.lan_dev.ports="$port"
  end
end
echo "$green""LAN bridge (br-lan) configured with ""$reset"(count $required_ports)"$green"" ports.""$reset"

# WAN Bridge (br-wan) - idempotent approach
echo "$blue""Configuring WAN bridge (br-wan)...""$reset"
uci set network.wan_dev='device'
uci set network.wan_dev.name='br-wan'
uci set network.wan_dev.type='bridge'

# First check if ports are already configured
set current_ports (uci -q get network.wan_dev.ports 2>/dev/null | string split " ")
if test (count $current_ports) -gt 0
  echo "$yellow""Existing WAN ports found: ""$reset"(string join ", " $current_ports)
  uci delete network.wan_dev.ports
  echo "$green""Cleaned up existing WAN bridge ports.""$reset"
end

# Add WAN port with proper logging
echo "$blue""Adding port lan2 to WAN bridge...""$reset"
uci add_list network.wan_dev.ports='lan2'
echo "$green""WAN bridge (br-wan) configured successfully.""$reset"

# Define all VLANs with properly structured data - idempotent approach
echo "$purple""Configuring VLANs...""$reset"

# First check for existing VLANs that might need cleanup
set existing_vlans
for vlan_id in 1 10 20 70 80 90
  set vlan_name "vlan$vlan_id"
  if uci -q get network.$vlan_name > /dev/null
    set -a existing_vlans $vlan_name
  end
end

if test (count $existing_vlans) -gt 0
  echo "$yellow""Found ""$reset"(count $existing_vlans)"$yellow"" existing VLANs to clean up""$reset"
  # Show which VLANs will be reconfigured
  echo "$yellow""VLANs to be reconfigured: ""$reset"(string join ", " $existing_vlans)
end

# Define VLANs as an array with name, type, device, vlan ID, and ports
# Format: "vlan_name type device vlan_id port1 port2 port3..."
# Where each port has a format like "interface:tag" where tag can be:
#   t = tagged (trunk)
#   u = untagged (access)
#   * = primary port (for untagged traffic)
#
# Network VLAN structure:
# - vlan1 (Core): Primary network for trusted devices
# - vlan10 (Nexus): Specialized network for specific services
# - vlan20 (Nodes): Network for server nodes and infrastructure
# - vlan70 (Meta): Network for metadata and management
# - vlan80 (IoT): Network for Internet of Things devices
# - vlan90 (Guest): Public network for guests with limited access
#
set -l vlans \
  "vlan1 bridge-vlan br-lan 1 eth1:t lan1:u* lan3:u* lan4:u* lan5:t" \
  "vlan10 bridge-vlan br-lan 10 eth1:u* lan1:t lan3:t lan4:t lan5:u*" \
  "vlan20 bridge-vlan br-lan 20 eth1:t lan1:t lan3:t lan4:t lan5:t" \
  "vlan70 bridge-vlan br-lan 70 eth1:t lan1:t lan3:t lan4:t lan5:t" \
  "vlan80 bridge-vlan br-lan 80 eth1:t lan1:t lan3:t lan4:t lan5:t" \
  "vlan90 bridge-vlan br-lan 90 eth1:t lan1:t lan3:t lan4:t lan5:t"

# Process each VLAN definition - enhanced for idempotency
for vlan in $vlans
  # Split the definition into parts
  set -l parts (string split " " -- "$vlan")
  
  # Parse VLAN parameters
  set -l name $parts[1]
  set -l type $parts[2]
  set -l device $parts[3]
  set -l id $parts[4]
  
  # Extract ports - all remaining parts
  set -l ports $parts[5..-1]

  # Check if this VLAN already exists
  set needs_create true
  if uci -q get network.$name > /dev/null
    echo "$yellow""VLAN $name already exists, reconfiguring...""$reset"
    set needs_create false
  else
    echo "$blue""Creating new VLAN: $name ($device.$id)...""$reset"
  end

  # Configure the VLAN
  uci set network.$name="$type"
  uci set network.$name.device="$device"
  uci set network.$name.vlan="$id"
  
  # Clear existing ports
  set current_ports (uci -q get network.$name.ports 2>/dev/null | string split " ")
  if test (count $current_ports) -gt 0
    echo "$yellow""Clearing existing ports for $name: ""$reset"(string join ", " $current_ports)
    uci delete network.$name.ports
  end
  
  # Add ports one by one
  for port in $ports
    echo "$blue""Adding port $port to $name...""$reset"
    uci add_list network.$name.ports="$port"
  end
  
  if test $needs_create = true
    echo "$green""VLAN $name created successfully.""$reset"
  else
    echo "$green""VLAN $name reconfigured successfully.""$reset"
  end
end

# Define network interfaces mapped to VLANs - idempotent approach
echo "$purple""Defining logical network interfaces...""$reset"

# Check for existing interfaces that might be reconfigured
set existing_interfaces
for iface in core nexus nodes meta iot guest
  if uci -q get network.$iface > /dev/null
    set -a existing_interfaces $iface
  end
end

if test (count $existing_interfaces) -gt 0
  echo "$yellow""Found ""$reset"(count $existing_interfaces)"$yellow"" existing interfaces to reconfigure""$reset"
  echo "$yellow""Interfaces to be reconfigured: ""$reset"(string join ", " $existing_interfaces)
end

# Define network interfaces mapped to VLANs
set -l interfaces \
  "core static br-lan.1 10.0.0.1 255.255.255.0" \
  "nexus static br-lan.10 10.0.10.1 255.255.255.0" \
  "nodes static br-lan.20 10.0.20.1 255.255.255.0" \
  "meta static br-lan.70 10.0.70.1 255.255.255.0" \
  "iot static br-lan.80 10.0.80.1 255.255.255.0" \
  "guest static br-lan.90 192.168.90.1 255.255.255.0"

# Process each interface - enhanced for idempotency
for iface in $interfaces
  set -l parts (string split " " -- "$iface")
  set -l name $parts[1]
  set -l proto $parts[2]
  set -l device $parts[3]
  set -l ipaddr $parts[4]
  set -l netmask $parts[5]

  # Check if interface already exists
  if uci -q get network.$name > /dev/null
    echo "$yellow""Interface $name already exists, reconfiguring...""$reset"
  else
    echo "$blue""Creating new interface: $name...""$reset"
  end

  # Configure the interface
  uci set network.$name='interface'
  uci set network.$name.proto="$proto"
  uci set network.$name.device="$device"
  uci set network.$name.ipaddr="$ipaddr"
  uci set network.$name.netmask="$netmask"
  echo "$green""Interface $name configured successfully: $ipaddr/$netmask on $device""$reset"
end

# WAN interface - idempotent approach
echo "$blue""Configuring WAN interface...""$reset"
if uci -q get network.wan > /dev/null
  echo "$yellow""WAN interface already exists, reconfiguring...""$reset"
else
  echo "$blue""Creating new WAN interface...""$reset"
end
uci set network.wan='interface'
uci set network.wan.proto='dhcp'
uci set network.wan.device='br-wan'
uci set network.wan.hostname='router'  # Use generic hostname instead of real one
uci set network.wan.peerdns='0'        # Don't overwrite DNS settings with ISP DNS
uci set network.wan.sendhost='0'       # Don't send hostname with DHCP requests
uci set network.wan.delegate='0'       # Don't delegate DHCPv6 prefix
uci set network.wan.macaddr='random'   # Use random MAC for privacy (if supported)
echo "$green""WAN interface configured with enhanced security settings""$reset"

# WireGuard interface - idempotent approach
echo "$blue""Configuring WireGuard interface...""$reset"
if uci -q get network.wireguard > /dev/null
  echo "$yellow""WireGuard interface already exists, reconfiguring...""$reset"
else
  echo "$blue""Creating new WireGuard interface...""$reset"
end
uci set network.wireguard='interface'
uci set network.wireguard.proto='wireguard'
uci set network.wireguard.ipaddr="$WIREGUARD_IP"
uci set network.wireguard.netmask='255.255.255.0'
echo "$green""WireGuard interface configured successfully.""$reset"

# Important: Don't commit here - the parent script (01-install.sh) or
# another dedicated script handles committing changes after all configurations
# are applied. This ensures all UCI configuration is committed at once.

echo "$green""Network configuration completed successfully.""$reset"