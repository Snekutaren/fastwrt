#!/bin/sh

set -e  # Exit on any error

# Error handling improvements
trap 'echo "Error occurred during DHCP configuration. Exiting."; exit 1' ERR

# Log the purpose of the script
echo "Starting DHCP configuration script to set up DHCP and DNS services..."

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
echo "Adding static lease for rog_eth..."
uci set dhcp.rog_eth=host
uci set dhcp.rog_eth.name='rog-eth'
uci set dhcp.rog_eth.mac='CC:28:AA:38:71:8D'
uci set dhcp.rog_eth.ip='10.0.0.60'
uci set dhcp.rog_eth.interface='core'  # Fixed: Use interface, not tag

echo "Adding static lease for e800_eth..."
uci set dhcp.e800_eth=host
uci set dhcp.e800_eth.name='e800-eth'
uci set dhcp.e800_eth.mac='40:B0:34:F7:A3:40'
uci set dhcp.e800_eth.ip='10.0.0.70'
uci set dhcp.e800_eth.interface='core'

echo "Static lease configuration completed successfully."
