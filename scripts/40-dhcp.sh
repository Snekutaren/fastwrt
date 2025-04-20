#!/bin/sh

set -e  # Exit on any error

# Error handling improvements
trap 'echo "Error occurred during DHCP configuration. Exiting."; exit 1' ERR

# Log the purpose of the script
echo "Starting DHCP configuration script to set up DHCP and DNS services..."

# Ensure the script runs from its own directory
cd "$BASE_DIR"

# Debugging: Log the current working directory
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

# Configure WAN DHCP settings
echo "Configuring WAN DHCP settings..."
uci set dhcp.wan=dhcp
uci set dhcp.wan.interface='wan'
uci set dhcp.wan.ignore='1'

# DHCP Pools
echo "Configuring DHCP pools for zones: core, nexus, nodes..."
for zone in core nexus nodes; do
  uci set dhcp.$zone=dhcp
  uci set dhcp.$zone.interface="$zone"
  uci set dhcp.$zone.start='200'
  uci set dhcp.$zone.limit='55'
  uci set dhcp.$zone.leasetime='12h'
done

echo "DHCP pool configuration completed successfully."

# Static Leases
# Removed static lease for rog_eth
# Removed static lease for e800_eth

echo "Static lease configuration completed successfully."

# Process the maclist file line by line instead of sourcing it
MACLIST_PATH="$BASE_DIR/maclist"
if [ -f "$MACLIST_PATH" ]; then
  echo "Maclist file found at: $MACLIST_PATH"
  while IFS= read -r line; do
    # Process each line of the maclist file
    echo "Processing line: $line"
    mac=$(echo "$line" | cut -d',' -f1)
    ip=$(echo "$line" | cut -d',' -f2)
    hostname=$(echo "$line" | cut -d',' -f3)
    ssid=$(echo "$line" | cut -d',' -f4)
    # Add logic to handle the extracted values as needed
    echo "MAC: $mac, IP: $ip, Hostname: $hostname, SSID: $ssid"
  done < "$MACLIST_PATH"
else
  echo "Error: Maclist file not found at $MACLIST_PATH. Please create a 'maclist' file."
  exit 1
fi

# Update static IP and hostname assignment logic to handle empty SSID field
MACLIST_PATH="$BASE_DIR/maclist"
if [ -f "$MACLIST_PATH" ]; then
  echo "Maclist file found at: $MACLIST_PATH"
  echo "Assigning static IPs and hostnames based on MAC list..."
  while IFS= read -r line; do
    mac=$(echo "$line" | cut -d',' -f1)
    ip=$(echo "$line" | cut -d',' -f2)
    hostname=$(echo "$line" | cut -d',' -f3)
    ssid=$(echo "$line" | cut -d',' -f4)
    if [ -n "$mac" ] && [ -n "$ip" ] && [ -n "$hostname" ]; then
      echo "Assigning IP $ip and hostname $hostname to MAC $mac..."
      uci add dhcp host
      uci set dhcp.@host[-1].mac="$mac"
      uci set dhcp.@host[-1].ip="$ip"
      uci set dhcp.@host[-1].name="$hostname"
    fi
  done < "$MACLIST_PATH"
else
  echo "Error: Maclist file not found at $MACLIST_PATH. Please create a 'maclist' file."
  exit 1
fi

# Commit the changes
uci commit dhcp
