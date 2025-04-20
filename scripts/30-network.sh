#!/bin/sh

set -e  # Exit on any error

# Log the start of the script
echo "Starting network configuration..."

### --- Network Configuration ---
# Clean up existing configs (safely)
echo "Cleaning up existing network configurations..."
for config in lan_dev wan_dev br-lan br-wan lan; do
  echo "Attempting to delete network.$config..."
  if uci delete network.$config 2>/dev/null; then
    echo "Deleted network.$config."
  else
    echo "Notice: network.$config not found, skipping deletion."
  fi
done
echo "Network configuration cleanup completed."

# Clean up orphaned device entries
echo "Cleaning up orphaned device entries..."
for device in $(uci show network | grep -E '@device\[[0-9]+\]' | cut -d. -f2 | cut -d= -f1); do
  echo "Attempting to delete network.$device..."
  if uci delete network.$device 2>/dev/null; then
    echo "Deleted network.$device."
  else
    echo "Notice: network.$device not found, skipping deletion."
  fi
done
echo "Orphaned device cleanup completed."

# Loopback (only if not already defined)
echo "Configuring loopback interface..."
if ! uci get network.loopback >/dev/null; then
  uci set network.loopback=interface
  uci set network.loopback.device='lo'
  uci set network.loopback.proto='static'
  uci set network.loopback.ipaddr='127.0.0.1'
  uci set network.loopback.netmask='255.0.0.0'
  echo "Loopback interface configured."
else
  echo "Loopback interface already configured, skipping."
fi

# Global settings
echo "Configuring global network settings..."
uci set network.globals=globals
uci set network.globals.ula_prefix='fdd7:1414:1d85::/48'
uci set network.globals.packet_steering='1'
echo "Global network settings configured."

# LAN Bridge (br-lan)
echo "Configuring LAN bridge (br-lan)..."
uci set network.lan_dev=device
uci set network.lan_dev.name='br-lan'
uci set network.lan_dev.type='bridge'
echo "Cleaning up existing ports for LAN bridge to avoid duplicates..."
if uci delete network.lan_dev.ports 2>/dev/null; then
  echo "Deleted network.lan_dev.ports."
else
  echo "Notice: network.lan_dev.ports not found, skipping deletion."
fi
# Adding logging for port additions
for port in eth1 lan1 lan3 lan4 lan5; do
  echo "Adding port $port to network.lan_dev.ports..."
  uci add_list network.lan_dev.ports="$port"
done
echo "LAN bridge (br-lan) configured successfully."

# WAN Bridge (br-wan)
echo "Configuring WAN bridge (br-wan)..."
uci set network.wan_dev=device
uci set network.wan_dev.name='br-wan'
uci set network.wan_dev.type='bridge'
echo "Cleaning up existing ports for WAN bridge to avoid duplicates..."
if uci delete network.wan_dev.ports 2>/dev/null; then
  echo "Deleted network.wan_dev.ports."
else
  echo "Notice: network.wan_dev.ports not found, skipping deletion."
fi
uci add_list network.wan_dev.ports='lan2'
echo "WAN bridge (br-wan) configured successfully."

# VLANs (br-lan)
echo "Configuring VLANs for LAN bridge (br-lan)..."
uci set network.vlan1=bridge-vlan
uci set network.vlan1.device='br-lan'
uci set network.vlan1.vlan='1'
echo "Cleaning up existing ports for VLAN 1 to avoid duplicates..."
if uci delete network.vlan1.ports 2>/dev/null; then
  echo "Deleted network.vlan1.ports."
else
  echo "Notice: network.vlan1.ports not found, skipping deletion."
fi
# Adding logging for port additions
for port in 'lan1:u*' 'lan3:u*' 'lan5:u*'; do
  echo "Adding port $port to network.vlan1.ports..."
  uci add_list network.vlan1.ports="$port"
done
echo "VLAN 1 for LAN bridge (br-lan) configured successfully."

# VLAN for WAN (br-wan)
echo "Configuring VLAN 100 for WAN bridge (br-wan)..."
uci set network.vlan100=bridge-vlan
uci set network.vlan100.device='br-wan'
uci set network.vlan100.vlan='100'
echo "Cleaning up existing ports for VLAN 100 to avoid duplicates..."
if uci delete network.vlan100.ports 2>/dev/null; then
  echo "Deleted network.vlan100.ports."
else
  echo "Notice: network.vlan100.ports not found, skipping deletion."
fi
# Adding logging for port additions
echo "Adding port lan2:u* to network.vlan100.ports..."
uci add_list network.vlan100.ports='lan2:u*'
echo "VLAN 100 for WAN bridge (br-wan) configured successfully."

echo "Network configuration completed successfully."

### --- Interfaces ---
# Core (VLAN 1)
echo "Configuring core interface (VLAN 1)..."
uci set network.core=interface
uci set network.core.device='br-lan.1'
uci set network.core.proto='static'
uci set network.core.ipaddr='10.0.0.1'
uci set network.core.netmask='255.255.255.0'
echo "Core interface configured."

# Nexus (VLAN 10)
echo "Configuring nexus interface (VLAN 10)..."
uci set network.nexus=interface
uci set network.nexus.device='br-lan.10'
uci set network.nexus.proto='static'
uci set network.nexus.ipaddr='10.0.10.1'
uci set network.nexus.netmask='255.255.255.0'
echo "Nexus interface configured."

# Nodes (VLAN 20)
echo "Configuring nodes interface (VLAN 20)..."
uci set network.nodes=interface
uci set network.nodes.device='br-lan.20'
uci set network.nodes.proto='static'
uci set network.nodes.ipaddr='10.0.20.1'
uci set network.nodes.netmask='255.255.255.0'
echo "Nodes interface configured."

# WAN (VLAN 100)
echo "Configuring WAN interface (VLAN 100)..."
uci set network.wan=interface
uci set network.wan.device='br-wan.100'
uci set network.wan.proto='dhcp'
echo "WAN interface configured."

# WAN IPv6 (disabled)
echo "Configuring WAN IPv6 interface (disabled)..."
uci set network.wan6=interface
uci set network.wan6.device='br-wan.100'
uci set network.wan6.proto='dhcpv6'
uci set network.wan6.disabled='1'
echo "WAN IPv6 interface configured (disabled)."

echo "Network configuration completed successfully."