#!/usr/bin/fish
# FastWrt network configuration - Implementation using fish shell
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
echo "$green""Starting network configuration...""$reset"

### --- Network Configuration ---
# Clean up existing configs (safely)
echo "$blue""Cleaning up existing network configurations...""$reset"
for config in lan_dev wan_dev br-lan br-wan lan
  echo "Attempting to delete network.$config..."
  if uci delete network.$config 2>/dev/null
    echo "$green""Deleted network.$config.""$reset"
  else
    echo "$yellow""Notice: network.$config not found, skipping deletion.""$reset"
  end
end
echo "$green""Network configuration cleanup completed.""$reset"

# Clean up orphaned device entries
echo "$blue""Cleaning up orphaned device entries...""$reset"
for device in (uci show network | grep -E '@device\[[0-9]+\]' | cut -d. -f2 | cut -d= -f1)
  echo "Attempting to delete network.$device..."
  if uci delete network."$device" 2>/dev/null
    echo "$green""Deleted network.$device.""$reset"
  else
    echo "$yellow""Notice: network.$device not found, skipping deletion.""$reset"
  end
end
echo "$green""Orphaned device cleanup completed.""$reset"

# Loopback (only if not already defined)
echo "$blue""Configuring loopback interface...""$reset"
if not uci get network.loopback > /dev/null 2>&1
  uci set network.loopback='interface'
  uci set network.loopback.device='lo'
  uci set network.loopback.proto='static'
  uci set network.loopback.ipaddr='127.0.0.1'
  uci set network.loopback.netmask='255.0.0.0'
  echo "$green""Loopback interface configured.""$reset"
else
  echo "$yellow""Loopback interface already configured, skipping.""$reset"
end

# Global settings
echo "$blue""Configuring global network settings...""$reset"
uci set network.globals='globals'
uci set network.globals.ula_prefix='fdd7:1414:1d85::/48'
uci set network.globals.packet_steering='1'
echo "$green""Global network settings configured.""$reset"

# LAN Bridge (br-lan)
echo "$blue""Configuring LAN bridge (br-lan)...""$reset"
uci set network.lan_dev='device'
uci set network.lan_dev.name='br-lan'
uci set network.lan_dev.type='bridge'
echo "Cleaning up existing ports for LAN bridge to avoid duplicates..."
if uci delete network.lan_dev.ports 2>/dev/null
  echo "$green""Deleted network.lan_dev.ports.""$reset"
else
  echo "$yellow""Notice: network.lan_dev.ports not found, skipping deletion.""$reset"
end
# Adding logging for port additions
for port in eth1 lan1 lan3 lan4 lan5
  echo "Adding port $port to network.lan_dev.ports..."
  uci add_list network.lan_dev.ports="$port"
end
echo "$green""LAN bridge (br-lan) configured successfully.""$reset"

# WAN Bridge (br-wan)
echo "$blue""Configuring WAN bridge (br-wan)...""$reset"
uci set network.wan_dev='device'
uci set network.wan_dev.name='br-wan'
uci set network.wan_dev.type='bridge'
echo "Cleaning up existing ports for WAN bridge to avoid duplicates..."
if uci delete network.wan_dev.ports 2>/dev/null
  echo "$green""Deleted network.wan_dev.ports.""$reset"
else
  echo "$yellow""Notice: network.wan_dev.ports not found, skipping deletion.""$reset"
end
uci add_list network.wan_dev.ports='lan2'
echo "$green""WAN bridge (br-wan) configured successfully.""$reset"

# Define all VLANs with properly structured data
echo "$purple""Configuring VLANs...""$reset"

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

# Process each VLAN definition
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

  echo "$blue""Configuring $name ($device.$id)...""$reset"
  uci set network.$name="$type"
  uci set network.$name.device="$device"
  uci set network.$name.vlan="$id"
  
  # Clear existing ports
  if uci delete network.$name.ports 2>/dev/null
    echo "$green""Deleted network.$name.ports.""$reset"
  else
    echo "$yellow""Notice: network.$name.ports not found, skipping deletion.""$reset"
  end
  
  # Add ports one by one
  for port in $ports
    echo "Adding port $port to network.$name.ports..."
    uci add_list network.$name.ports="$port"
  end
  echo "$green""$name configured successfully.""$reset"
end

# After configuring VLANs, explicitly define all required interfaces
echo "$purple""Defining logical network interfaces...""$reset"

# Define network interfaces mapped to VLANs
set -l interfaces \
  "core static br-lan.1 10.0.0.1 255.255.255.0" \
  "nexus static br-lan.10 10.0.10.1 255.255.255.0" \
  "nodes static br-lan.20 10.0.20.1 255.255.255.0" \
  "meta static br-lan.70 10.0.70.1 255.255.255.0" \
  "iot static br-lan.80 10.0.80.1 255.255.255.0" \
  "guest static br-lan.90 192.168.90.1 255.255.255.0"

# Process each interface
for iface in $interfaces
  set -l parts (string split " " -- "$iface")
  set -l name $parts[1]
  set -l proto $parts[2]
  set -l device $parts[3]
  set -l ipaddr $parts[4]
  set -l netmask $parts[5]

  echo "$blue""Configuring interface $name on device $device with IP $ipaddr/$netmask...""$reset"
  uci set network.$name='interface'
  uci set network.$name.proto="$proto"
  uci set network.$name.device="$device"
  uci set network.$name.ipaddr="$ipaddr"
  uci set network.$name.netmask="$netmask"
  echo "$green""$name interface configured successfully.""$reset"
end

# WAN interface (for internet connectivity)
echo "$blue""Configuring WAN interface...""$reset"
uci set network.wan='interface'
uci set network.wan.proto='dhcp'
uci set network.wan.device='br-wan'

# WireGuard interface (if needed)
echo "$blue""Configuring WireGuard interface...""$reset"
uci set network.wireguard='interface'
uci set network.wireguard.proto='wireguard'
uci set network.wireguard.ipaddr="$WIREGUARD_IP"
uci set network.wireguard.netmask='255.255.255.0'

# Important: Don't commit here - the parent script (01-install.sh) or
# another dedicated script handles committing changes after all configurations
# are applied. This ensures all UCI configuration is committed at once.

echo "$green""Network configuration completed successfully.""$reset"