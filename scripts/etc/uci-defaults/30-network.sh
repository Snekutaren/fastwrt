#!/usr/bin/fish
# FastWrt network configuration - Pure fish implementation

# Ensure the script runs from its own directory
cd $BASE_DIR
echo "Current working directory: "(pwd)

# Log the start of the script
echo "Starting network configuration..."

### --- Network Configuration ---
# Clean up existing configs (safely)
echo "Cleaning up existing network configurations..."
for config in lan_dev wan_dev br-lan br-wan lan
  echo "Attempting to delete network.$config..."
  if uci delete network.$config 2>/dev/null
    echo "Deleted network.$config."
  else
    echo "Notice: network.$config not found, skipping deletion."
  end
end
echo "Network configuration cleanup completed."

# Clean up orphaned device entries
echo "Cleaning up orphaned device entries..."
for device in (uci show network | grep -E '@device\[[0-9]+\]' | cut -d. -f2 | cut -d= -f1)
  echo "Attempting to delete network.$device..."
  if uci delete network."$device" 2>/dev/null
    echo "Deleted network.$device."
  else
    echo "Notice: network.$device not found, skipping deletion."
  end
end
echo "Orphaned device cleanup completed."

# Loopback (only if not already defined)
echo "Configuring loopback interface..."
if not uci get network.loopback > /dev/null 2>&1
  uci set network.loopback='interface'
  uci set network.loopback.device='lo'
  uci set network.loopback.proto='static'
  uci set network.loopback.ipaddr='127.0.0.1'
  uci set network.loopback.netmask='255.0.0.0'
  echo "Loopback interface configured."
else
  echo "Loopback interface already configured, skipping."
end

# Global settings
echo "Configuring global network settings..."
uci set network.globals='globals'
uci set network.globals.ula_prefix='fdd7:1414:1d85::/48'
uci set network.globals.packet_steering='1'
echo "Global network settings configured."

# LAN Bridge (br-lan)
echo "Configuring LAN bridge (br-lan)..."
uci set network.lan_dev='device'
uci set network.lan_dev.name='br-lan'
uci set network.lan_dev.type='bridge'
echo "Cleaning up existing ports for LAN bridge to avoid duplicates..."
if uci delete network.lan_dev.ports 2>/dev/null
  echo "Deleted network.lan_dev.ports."
else
  echo "Notice: network.lan_dev.ports not found, skipping deletion."
end
# Adding logging for port additions
for port in eth1 lan1 lan3 lan4 lan5
  echo "Adding port $port to network.lan_dev.ports..."
  uci add_list network.lan_dev.ports="$port"
end
echo "LAN bridge (br-lan) configured successfully."

# WAN Bridge (br-wan)
echo "Configuring WAN bridge (br-wan)..."
uci set network.wan_dev='device'
uci set network.wan_dev.name='br-wan'
uci set network.wan_dev.type='bridge'
echo "Cleaning up existing ports for WAN bridge to avoid duplicates..."
if uci delete network.wan_dev.ports 2>/dev/null
  echo "Deleted network.wan_dev.ports."
else
  echo "Notice: network.wan_dev.ports not found, skipping deletion."
end
uci add_list network.wan_dev.ports='lan2'
echo "WAN bridge (br-wan) configured successfully."

# Define all VLANs mentioned in the documentation
echo "Configuring all network VLANs..."

# VLAN 1 (Core)
echo "Configuring VLAN 1 for Core network..."
uci set network.vlan1='bridge-vlan'
uci set network.vlan1.device='br-lan'
uci set network.vlan1.vlan='1'
echo "Cleaning up existing ports for VLAN 1 to avoid duplicates..."
if uci delete network.vlan1.ports 2>/dev/null
  echo "Deleted network.vlan1.ports."
else
  echo "Notice: network.vlan1.ports not found, skipping deletion."
end
# Adding logging for port additions
for port in 'lan1:u*' 'lan3:u*' 'lan5:u*'
  echo "Adding port $port to network.vlan1.ports..."
  uci add_list network.vlan1.ports="$port"
end
echo "VLAN 1 for Core network configured successfully."

# VLAN 10 (Nexus)
echo "Configuring VLAN 10 for Nexus network..."
uci set network.vlan10='bridge-vlan'
uci set network.vlan10.device='br-lan'
uci set network.vlan10.vlan='10'
echo "VLAN 10 for Nexus network configured successfully."

# VLAN 20 (Nodes)
echo "Configuring VLAN 20 for Nodes network..."
uci set network.vlan20='bridge-vlan'
uci set network.vlan20.device='br-lan'
uci set network.vlan20.vlan='20'
echo "VLAN 20 for Nodes network configured successfully."

# VLAN 70 (Meta)
echo "Configuring VLAN 70 for Meta network..."
uci set network.vlan70='bridge-vlan'
uci set network.vlan70.device='br-lan'
uci set network.vlan70.vlan='70'
echo "VLAN 70 for Meta network configured successfully."

# VLAN 80 (IoT)
echo "Configuring VLAN 80 for IoT network..."
uci set network.vlan80='bridge-vlan'
uci set network.vlan80.device='br-lan'
uci set network.vlan80.vlan='80'
echo "VLAN 80 for IoT network configured successfully."

# VLAN 90 (Guest)
echo "Configuring VLAN 90 for Guest network..."
uci set network.vlan90='bridge-vlan'
uci set network.vlan90.device='br-lan'
uci set network.vlan90.vlan='90'
echo "VLAN 90 for Guest network configured successfully."

# VLAN for WAN (br-wan)
echo "Configuring VLAN 100 for WAN bridge (br-wan)..."
uci set network.vlan100='bridge-vlan'
uci set network.vlan100.device='br-wan'
uci set network.vlan100.vlan='100'
echo "Cleaning up existing ports for VLAN 100 to avoid duplicates..."
if uci delete network.vlan100.ports 2>/dev/null
  echo "Deleted network.vlan100.ports."
else
  echo "Notice: network.vlan100.ports not found, skipping deletion."
end
# Adding logging for port additions
echo "Adding port lan2:u* to network.vlan100.ports..."
uci add_list network.vlan100.ports="lan2:u*"
echo "VLAN 100 for WAN bridge (br-wan) configured successfully."

echo "All VLANs configured successfully."

### --- Interfaces ---
# Define the order in which interfaces should be created (for GUI display order)
echo "Configuring network interfaces in specific order for GUI display..."

# Core (VLAN 1)
echo "Configuring core interface (VLAN 1)..."
uci set network.core='interface'
uci set network.core.device='br-lan.1'
uci set network.core.proto='static'
uci set network.core.ipaddr='10.0.0.1'
uci set network.core.netmask='255.255.255.0'
echo "Core interface configured."

# Nexus (VLAN 10)
echo "Configuring nexus interface (VLAN 10)..."
uci set network.nexus='interface'
uci set network.nexus.device='br-lan.10'
uci set network.nexus.proto='static'
uci set network.nexus.ipaddr='10.0.10.1'
uci set network.nexus.netmask='255.255.255.0'
echo "Nexus interface configured."

# Nodes (VLAN 20)
echo "Configuring nodes interface (VLAN 20)..."
uci set network.nodes='interface'
uci set network.nodes.device='br-lan.20'
uci set network.nodes.proto='static'
uci set network.nodes.ipaddr='10.0.20.1'
uci set network.nodes.netmask='255.255.255.0'
echo "Nodes interface configured."

# Meta (VLAN 70)
echo "Configuring meta interface (VLAN 70)..."
uci set network.meta='interface'
uci set network.meta.device='br-lan.70'
uci set network.meta.proto='static'
uci set network.meta.ipaddr='10.0.70.1'
uci set network.meta.netmask='255.255.255.0'
echo "Meta interface configured."

# IoT (VLAN 80)
echo "Configuring IoT interface (VLAN 80)..."
uci set network.iot='interface'
uci set network.iot.device='br-lan.80'
uci set network.iot.proto='static'
uci set network.iot.ipaddr='10.0.80.1'
uci set network.iot.netmask='255.255.255.0'
echo "IoT interface configured."

# Guest (VLAN 90)
echo "Configuring guest interface (VLAN 90)..."
uci set network.guest='interface'
uci set network.guest.device='br-lan.90'
uci set network.guest.proto='static'
uci set network.guest.ipaddr='192.168.90.1'
uci set network.guest.netmask='255.255.255.0'
echo "Guest interface configured."

# WireGuard Interface
echo "Configuring WireGuard interface..."
uci set network.wireguard='interface'
uci set network.wireguard.proto='static'
uci set network.wireguard.ipaddr="$WIREGUARD_IP"
uci set network.wireguard.netmask='255.255.255.0'
uci set network.wireguard.device='wg0'
echo "WireGuard interface configuration completed successfully."

# WAN (VLAN 100) - Configure this last for GUI order
echo "Configuring WAN interface (VLAN 100)..."
uci set network.wan='interface'
uci set network.wan.device='br-wan.100'
uci set network.wan.proto='dhcp'
echo "WAN interface configured."

# WAN IPv6 (VLAN 100, enabled/disabled based on ENABLE_WAN6)
if test "$ENABLE_WAN6" = true
  echo "Configuring WAN6 interface (VLAN 100, enabled)..."
  uci set network.wan6='interface'
  uci set network.wan6.device='br-wan.100'
  uci set network.wan6.proto='dhcpv6'
  uci set network.wan6.disabled='0'
  echo "WAN6 configured."
else
  echo "Configuring WAN6 interface (VLAN 100, disabled)..."
  uci set network.wan6='interface'
  uci set network.wan6.device='br-wan.100'
  uci set network.wan6.proto='dhcpv6'
  uci set network.wan6.disabled='1'
  echo "WAN6 disabled."
end

# Note: UCI commits are handled in 98-commit.sh
echo "Network configuration completed successfully. Changes will be applied during final commit."