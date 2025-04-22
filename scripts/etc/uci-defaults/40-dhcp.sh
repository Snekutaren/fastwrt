#!/usr/bin/fish
# FastWrt DHCP configuration - Pure fish implementation

# Ensure the script runs from its own directory
cd $BASE_DIR
echo "Current working directory: "(pwd)

# Delete any existing DHCP entries
echo "Cleaning up existing DHCP entries..."
for entry in (uci show dhcp | cut -d. -f2 | cut -d= -f1 | sort -u)
  echo "Deleting DHCP entry: $entry..."
  uci delete dhcp.$entry 2>/dev/null; or echo "Notice: DHCP entry $entry not found, skipping deletion."
end

### --- DHCP & DNS ---
# odhcpd (persistent leases)
echo "Setting odhcpd configuration..."
uci set dhcp.odhcpd='odhcpd'
uci set dhcp.odhcpd.maindhcp='0'
uci set dhcp.odhcpd.leasefile='/var/lib/odhcpd/leases'  # Fixed path
uci set dhcp.odhcpd.leasetrigger='/usr/sbin/odhcpd-update'
uci set dhcp.odhcpd.loglevel='4'

# Configure dnsmasq settings
echo "Configuring dnsmasq settings..."
uci add dhcp dnsmasq
uci set dhcp.@dnsmasq[-1]='dnsmasq'
uci set dhcp.@dnsmasq[-1].domainneeded='1'
uci set dhcp.@dnsmasq[-1].boguspriv='1'
uci set dhcp.@dnsmasq[-1].filterwin2k='0'
uci set dhcp.@dnsmasq[-1].localise_queries='1'
uci set dhcp.@dnsmasq[-1].rebind_protection='1'
uci set dhcp.@dnsmasq[-1].rebind_localhost='1'
uci set dhcp.@dnsmasq[-1].local='/lan/'
uci set dhcp.@dnsmasq[-1].domain='lan'
uci set dhcp.@dnsmasq[-1].expandhosts='1'
uci set dhcp.@dnsmasq[-1].nonegcache='0'
uci set dhcp.@dnsmasq[-1].cachesize='1000'
uci set dhcp.@dnsmasq[-1].authoritative='1'
uci set dhcp.@dnsmasq[-1].readethers='1'
uci set dhcp.@dnsmasq[-1].leasefile='/tmp/dhcp.leases'
uci set dhcp.@dnsmasq[-1].resolvfile='/tmp/resolv.conf.d/resolv.conf.auto'
uci set dhcp.@dnsmasq[-1].nonwildcard='1'
uci set dhcp.@dnsmasq[-1].localservice='1'
uci set dhcp.@dnsmasq[-1].ednspacket_max='1232'
uci set dhcp.@dnsmasq[-1].filter_aaaa='0'
uci set dhcp.@dnsmasq[-1].filter_a='0'

# Force clients to use router DNS
echo "Configuring DNS enforcement..."
uci set dhcp.@dnsmasq[-1].localservice='0'  # Allow requests from all networks, not just local
uci set dhcp.@dnsmasq[-1].noresolv='1'  # Don't read /etc/resolv.conf
uci add_list dhcp.@dnsmasq[-1].server='1.1.1.1'  # Cloudflare DNS
uci add_list dhcp.@dnsmasq[-1].server='9.9.9.9'  # Quad9 DNS
uci add_list dhcp.@dnsmasq[-1].server='8.8.8.8'  # Google DNS

# Configure DHCP for all interfaces
echo "Configuring DHCP pools for all interfaces..."
# List of interfaces and their subnets - ORDER MATTERS for GUI display order
set INTERFACES core nexus nodes meta iot guest wireguard wan

# Process all non-WAN interfaces first in the specified order
for interface in $INTERFACES
  # Skip WAN in the first pass - we'll add it last
  if test "$interface" = "wan"
    continue
  end
  
  echo "Configuring DHCP for $interface interface..."
  uci set dhcp.$interface='dhcp'
  uci set dhcp.$interface.interface="$interface"
  uci set dhcp.$interface.start='200'
  uci set dhcp.$interface.limit='54'  # Adjust to stay within valid range (200-254)
  uci set dhcp.$interface.leasetime='12h'

  # Special case for wireguard
  if test "$interface" = "wireguard"
    echo "Special configuration for WireGuard interface"
    uci set dhcp.$interface.ignore='1'  # Typically WireGuard doesn't need DHCP
  end

  # For guest network, configure different DNS to prevent internal network access
  if test "$interface" = "guest"
    echo "Setting public DNS for guest network"
    uci add_list dhcp.$interface.dhcp_option='6,8.8.8.8,8.8.4.4'  # Use Google DNS for guests
  end
end

# Now add WAN last to ensure it appears at the end of the list in GUI
echo "Configuring WAN DHCP settings (added last for GUI order)..."
uci set dhcp.wan='dhcp'
uci set dhcp.wan.interface='wan'
uci set dhcp.wan.ignore='1'

echo "DHCP pool configuration completed successfully."

# Process maclist.csv for static DHCP leases
set MACLIST_PATH "$BASE_DIR/maclist.csv"
if test -f "$MACLIST_PATH"
  echo "Processing maclist.csv for static DHCP leases..."
  set line_count 0
  
  # Using fish's builtin line reading capabilities
  while read -l line
    # Count lines for better debugging
    set line_count (math $line_count + 1)
    
    # Skip comment lines and empty lines with better detection
    if string match -q "#*" $line; or test -z (string trim "$line")
      continue
    end
    
    # Parse CSV line (mac,ip,name,network)
    set fields (string split "," $line)
    
    # Validate that we have all required fields
    if test (count $fields) -lt 4
      echo "Warning: Invalid line format in maclist.csv on line $line_count: $line"
      echo "Expected format: MAC,IP,NAME,NETWORK"
      continue
    end
    
    # Extract fields and validate
    set mac_addr (string trim "$fields[1]")
    set ip_addr (string trim "$fields[2]")
    set device_name (string trim "$fields[3]")
    set network_name (string trim "$fields[4]")
    
    # Skip if any required fields are empty
    if test -z "$mac_addr"; or test -z "$ip_addr"; or test -z "$device_name"
      echo "Warning: Missing required field in maclist.csv line $line_count: $line"
      continue
    end
    
    # Convert device name to a valid UCI section name (replace hyphens with underscores)
    set device_section (string replace -a "-" "_" "$device_name")
    
    echo "Setting up static lease for $device_name ($mac_addr -> $ip_addr)"
    
    # Add static lease with proper UCI syntax (no spaces before equals)
    uci set dhcp.$device_section='host'
    uci set dhcp.$device_section.name="$device_name"
    uci set dhcp.$device_section.mac="$mac_addr"
    uci set dhcp.$device_section.ip="$ip_addr"
    
    # Use network_name if provided, otherwise default to "core"
    if test -z "$network_name"
      set network_name "core"
    end
    uci set dhcp.$device_section.interface="$network_name"
  end < "$MACLIST_PATH"
  
  echo "Static lease configuration completed successfully."
else
  echo "Warning: maclist.csv not found at $MACLIST_PATH, skipping static lease configuration."
end

# Note: UCI commits are handled in 98-commit.sh
echo "DHCP and DNS configuration completed successfully. Changes will be applied during final commit."
