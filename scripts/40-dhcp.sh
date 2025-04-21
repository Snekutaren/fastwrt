#!/bin/sh
set -e  # Exit on any error
# Ensure the script runs from its own directory
cd "$BASE_DIR"
echo "Current working directory: $(pwd)"

# Delete any existing DHCP entries
echo "Cleaning up existing DHCP entries..."
for entry in $(uci show dhcp | cut -d. -f2 | cut -d= -f1 | sort -u); do
  echo "Deleting DHCP entry: $entry..."
  uci delete dhcp.$entry 2>/dev/null || echo "Notice: DHCP entry $entry not found, skipping deletion."
done

### --- DHCP & DNS ---
# odhcpd (persistent leases)
echo "Setting odhcpd configuration..."
uci set dhcp.odhcpd=odhcpd
uci set dhcp.odhcpd.maindhcp='0'
uci set dhcp.odhcpd.leasefile='/var/lib/odhcpd/leases'  # Fixed path
uci set dhcp.odhcpd.leasetrigger='/usr/sbin/odhcpd-update'
uci set dhcp.odhcpd.loglevel='4'

# Configure dnsmasq settings
echo "Configuring dnsmasq settings..."
uci add dhcp dnsmasq
uci set dhcp.@dnsmasq[0]=dnsmasq
uci set dhcp.@dnsmasq[0].domainneeded='1'
uci set dhcp.@dnsmasq[0].boguspriv='1'
uci set dhcp.@dnsmasq[0].filterwin2k='0'
uci set dhcp.@dnsmasq[0].localise_queries='1'
uci set dhcp.@dnsmasq[0].rebind_protection='1'
uci set dhcp.@dnsmasq[0].rebind_localhost='1'
uci set dhcp.@dnsmasq[0].local='/lan/'
uci set dhcp.@dnsmasq[0].domain='lan'
uci set dhcp.@dnsmasq[0].expandhosts='1'
uci set dhcp.@dnsmasq[0].nonegcache='0'
uci set dhcp.@dnsmasq[0].cachesize='1000'
uci set dhcp.@dnsmasq[0].authoritative='1'
uci set dhcp.@dnsmasq[0].readethers='1'
uci set dhcp.@dnsmasq[0].leasefile='/tmp/dhcp.leases'
uci set dhcp.@dnsmasq[0].resolvfile='/tmp/resolv.conf.d/resolv.conf.auto'
uci set dhcp.@dnsmasq[0].nonwildcard='1'
uci set dhcp.@dnsmasq[0].localservice='1'
uci set dhcp.@dnsmasq[0].ednspacket_max='1232'
uci set dhcp.@dnsmasq[0].filter_aaaa='0'
uci set dhcp.@dnsmasq[0].filter_a='0'

# Force clients to use router DNS
echo "Configuring DNS enforcement..."
uci set dhcp.@dnsmasq[0].localservice='0'  # Allow requests from all networks, not just local
uci set dhcp.@dnsmasq[0].noresolv='1'  # Don't read /etc/resolv.conf
uci add_list dhcp.@dnsmasq[0].server='1.1.1.1'  # Cloudflare DNS
uci add_list dhcp.@dnsmasq[0].server='9.9.9.9'  # Quad9 DNS
uci add_list dhcp.@dnsmasq[0].server='8.8.8.8'  # Google DNS

# Configure DHCP for all interfaces
echo "Configuring DHCP pools for all interfaces..."
# List of interfaces and their subnets - ORDER MATTERS for GUI display order
INTERFACES="core nexus nodes meta iot guest wireguard wan"

# Process WAN separately first to ensure it comes last in GUI
echo "Skipping WAN in first pass (will be added last)..."

# Process all non-WAN interfaces in the specified order
for interface in $INTERFACES; do
  # Skip WAN in the first pass - we'll add it last
  if [ "$interface" = "wan" ]; then
    continue
  fi
  
  echo "Configuring DHCP for $interface interface..."
  uci set dhcp.$interface=dhcp
  uci set dhcp.$interface.interface="$interface"
  uci set dhcp.$interface.start='200'
  uci set dhcp.$interface.limit='54'  # Adjust to stay within valid range (200-254)
  uci set dhcp.$interface.leasetime='12h'

  # Special case for wireguard
  if [ "$interface" = "wireguard" ]; then
    echo "Special configuration for WireGuard interface"
    uci set dhcp.$interface.ignore='1'  # Typically WireGuard doesn't need DHCP
  fi

  # For guest network, configure different DNS to prevent internal network access
  if [ "$interface" = "guest" ]; then
    echo "Setting public DNS for guest network"
    uci add_list dhcp.$interface.dhcp_option='6,8.8.8.8,8.8.4.4'  # Use Google DNS for guests
  fi
done

# Now add WAN last to ensure it appears at the end of the list in GUI
echo "Configuring WAN DHCP settings (added last for GUI order)..."
uci set dhcp.wan=dhcp
uci set dhcp.wan.interface='wan'
uci set dhcp.wan.ignore='1'

echo "DHCP pool configuration completed successfully."

# Process maclist.csv for static DHCP leases
MACLIST_PATH="$BASE_DIR/maclist.csv"
if [ -f "$MACLIST_PATH" ]; then
  echo "Processing maclist.csv for static DHCP leases..."
  while IFS=, read -r mac_addr ip_addr device_name network_name; do
    # Skip comment lines and empty lines
    case "$mac_addr" in
      \#*|"") continue ;;
    esac
    
    # Convert device name to a valid UCI section name (replace hyphens with underscores)
    device_section=$(echo "$device_name" | tr '-' '_')
    
    echo "Setting up static lease for $device_name ($mac_addr -> $ip_addr)"
    
    # Determine interface based on network_name (or use core as default)
    network="${network_name:-core}"
    
    # Add static lease
    uci set dhcp.$device_section=host
    uci set dhcp.$device_section.name="$device_name"
    uci set dhcp.$device_section.mac="$mac_addr"
    uci set dhcp.$device_section.ip="$ip_addr"
    uci set dhcp.$device_section.interface="$network"
  done < "$MACLIST_PATH"
  echo "Static lease configuration completed successfully."
else
  echo "Warning: maclist.csv not found at $MACLIST_PATH, skipping static lease configuration."
fi

# Commented out static leases as they are now handled by maclist.csv
# Static lease for rog-eth
#uci set dhcp.rog_eth=host
#uci set dhcp.rog_eth.name='rog-eth'
#uci set dhcp.rog_eth.mac='CC:28:AA:38:71:8D'
#uci set dhcp.rog_eth.ip='10.0.0.60'
#uci set dhcp.rog_eth.interface='core'
# Static lease for e800-eth
#uci set dhcp.e800_eth=host
#uci set dhcp.e800_eth.name='e800-eth'
#uci set dhcp.e800_eth.mac='40:B0:34:F7:A3:40'
#uci set dhcp.e800_eth.ip='10.0.0.70'
#uci set dhcp.e800_eth.interface='core'
#echo "Static lease configuration completed successfully."

uci commit dhcp
