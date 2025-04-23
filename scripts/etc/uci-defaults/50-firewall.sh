#!/usr/bin/fish
# FastWrt firewall configuration script - Implementation using fish shell
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
echo "$purple""Starting firewall configuration...""$reset"

### SECTION 1: DEFINE CONSTANTS AND MANAGEMENT IPs ###
# Define management IPs that should always have access
set -g MANAGEMENT_IPS "10.0.0.60"
echo "$blue""Management IPs with guaranteed access: $MANAGEMENT_IPS""$reset"

### SECTION 2: COMPLETE FIREWALL RESET ###
echo "$blue""Performing complete firewall reset...""$reset"

# Clear all firewall configuration completely
echo "$blue""Removing all existing firewall configuration...""$reset"

# Clear redirects with improved output
set redirect_count 0
while uci -q delete firewall.@redirect[0] > /dev/null
  set redirect_count (math $redirect_count + 1)
  if test "$DEBUG" = "true"
    echo "$green""Deleted firewall.@redirect[0]""$reset"
  end
end
if test $redirect_count -gt 0
  echo "$green""Deleted $redirect_count firewall redirects""$reset"
end

# Clear rules with improved output
set rule_count 0
while uci -q delete firewall.@rule[0] > /dev/null
  set rule_count (math $rule_count + 1)
  if test "$DEBUG" = "true"
    echo "$green""Deleted firewall.@rule[0]""$reset"
  end
end
if test $rule_count -gt 0
  echo "$green""Deleted $rule_count firewall rules""$reset"
end

# Clear forwarding with improved output
set forwarding_count 0
while uci -q delete firewall.@forwarding[0] > /dev/null
  set forwarding_count (math $forwarding_count + 1)
  if test "$DEBUG" = "true"
    echo "$green""Deleted firewall.@forwarding[0]""$reset"
  end
end
if test $forwarding_count -gt 0
  echo "$green""Deleted $forwarding_count firewall forwarding rules""$reset"
end

# Clear zones with improved output
set zone_count 0
while uci -q delete firewall.@zone[0] > /dev/null
  set zone_count (math $zone_count + 1)
  if test "$DEBUG" = "true"
    echo "$green""Deleted firewall.@zone[0]""$reset"
  end
end
if test $zone_count -gt 0
  echo "$green""Deleted $zone_count firewall zones""$reset"
end

echo "$green""Firewall configuration cleanup completed""$reset"

# Firewall Defaults (Drop All)
echo "$blue""Setting global firewall defaults...""$reset"
uci set firewall.@defaults[0].input='DROP'
uci set firewall.@defaults[0].output='DROP'
uci set firewall.@defaults[0].forward='DROP'
uci set firewall.@defaults[0].syn_flood='1'
uci set firewall.@defaults[0].drop_invalid='1'
uci set firewall.@defaults[0].flow_offloading='1'
uci set firewall.@defaults[0].flow_offloading_hw='1'

### SECTION 3: ANTI-LOCKOUT SAFETY RULES ###
echo "$blue""Adding anti-lockout safety rules...""$reset"

# Rule 1: Allow established connections (highest priority)
echo "$green""Creating rule for established connections...""$reset"
uci set firewall.allow_established='rule'
uci set firewall.allow_established.name='Allow-Established-Connections'
uci set firewall.allow_established.proto='all'
uci set firewall.allow_established.src='*'
uci set firewall.allow_established.dest='*'
uci set firewall.allow_established.target='ACCEPT'
uci set firewall.allow_established.extra='--ctstate RELATED,ESTABLISHED'
uci set firewall.allow_established.priority='1' # Highest priority (lower number)
uci set firewall.allow_established.enabled='1'
uci set firewall.allow_established.family='any' # Ensure IPv4 and IPv6

# Rule 2: Allow SSH access from management IP (second highest priority)
echo "$green""Creating rule for management IP access...""$reset"
uci set firewall.mgmt_access='rule'
uci set firewall.mgmt_access.name='Management-Access'
uci set firewall.mgmt_access.proto='tcp' # Limit to TCP for SSH
uci set firewall.mgmt_access.src='*'
uci set firewall.mgmt_access.src_ip="$MANAGEMENT_IPS"
uci set firewall.mgmt_access.dest_port='6622' # Limit to SSH port
uci set firewall.mgmt_access.target='ACCEPT'
uci set firewall.mgmt_access.priority='2'
uci set firewall.mgmt_access.enabled='1'
uci set firewall.mgmt_access.family='any' # Ensure IPv4 and IPv6

# Rule 3: Allow SSH access from core network
uci set firewall.ssh_from_core='rule'
uci set firewall.ssh_from_core.name='SSH-from-Core'
uci set firewall.ssh_from_core.src='core'
uci set firewall.ssh_from_core.proto='tcp'
uci set firewall.ssh_from_core.dest_port='6622'
uci set firewall.ssh_from_core.target='ACCEPT'
uci set firewall.ssh_from_core.priority='3'
uci set firewall.ssh_from_core.enabled='1'
uci set firewall.ssh_from_core.family='any' # Ensure IPv4 and IPv6

# Rule 4: Allow SSH access from WireGuard
uci set firewall.ssh_from_wireguard='rule'
uci set firewall.ssh_from_wireguard.name='SSH-from-WireGuard'
uci set firewall.ssh_from_wireguard.src='wireguard'
uci set firewall.ssh_from_wireguard.proto='tcp'
uci set firewall.ssh_from_wireguard.dest_port='6622'
uci set firewall.ssh_from_wireguard.target='ACCEPT'
uci set firewall.ssh_from_wireguard.priority='3'
uci set firewall.ssh_from_wireguard.enabled='1'
uci set firewall.ssh_from_wireguard.family='any' # Ensure IPv4 and IPv6

# Rule 5: Enable web access from core network
uci set firewall.web_from_core='rule'
uci set firewall.web_from_core.name='Web-from-Core'
uci set firewall.web_from_core.src='core'
uci set firewall.web_from_core.proto='tcp'
uci set firewall.web_from_core.dest_port='80 443'
uci set firewall.web_from_core.target='ACCEPT'
uci set firewall.web_from_core.priority='4'
uci set firewall.web_from_core.enabled='1'
uci set firewall.web_from_core.family='any' # Ensure IPv4 and IPv6

### SECTION 4: ESSENTIAL OPENWRT STANDARD RULES ###
echo "$blue""Adding OpenWrt standard essential rules...""$reset"

# Allow DHCP for all interfaces
echo "$green""Creating DHCP rules...""$reset"
uci set firewall.allow_dhcp='rule'
uci set firewall.allow_dhcp.name='Allow-DHCP-All'
uci set firewall.allow_dhcp.proto='udp'
uci set firewall.allow_dhcp.src='*'
uci set firewall.allow_dhcp.dest_port='67 68'
uci set firewall.allow_dhcp.target='ACCEPT'
uci set firewall.allow_dhcp.priority='10'
uci set firewall.allow_dhcp.enabled='1'

# Allow DHCP renewal from WAN
echo "$green""Creating DHCP renewal rule...""$reset"
uci set firewall.allow_dhcp_renew='rule'
uci set firewall.allow_dhcp_renew.name='Allow-DHCP-Renew'
uci set firewall.allow_dhcp_renew.src='wan'
uci set firewall.allow_dhcp_renew.proto='udp'
uci set firewall.allow_dhcp_renew.dest_port='68'
uci set firewall.allow_dhcp_renew.target='ACCEPT'
uci set firewall.allow_dhcp_renew.family='ipv4'
uci set firewall.allow_dhcp_renew.priority='10'
uci set firewall.allow_dhcp_renew.enabled='1'

# Allow basic ICMP (ping)
echo "$green""Creating ping rule...""$reset"
uci set firewall.allow_ping='rule'
uci set firewall.allow_ping.name='Allow-Ping'
uci set firewall.allow_ping.proto='icmp'
uci set firewall.allow_ping.icmp_type='echo-request'
uci set firewall.allow_ping.family='ipv4'
uci set firewall.allow_ping.target='ACCEPT'
uci set firewall.allow_ping.enabled='1'

# Add IPv6 rules if IPv6 is enabled
if test "$ENABLE_WAN6" = "true"
    echo "$green""Creating IPv6 rules...""$reset"
    uci set firewall.allow_icmpv6_input='rule'
    uci set firewall.allow_icmpv6_input.name='Allow-ICMPv6-Input'
    uci set firewall.allow_icmpv6_input.proto='icmp'
    uci set firewall.allow_icmpv6_input.icmp_type='echo-request destination-unreachable packet-too-big time-exceeded bad-header unknown-header-type router-solicitation neighbour-solicitation router-advertisement neighbour-advertisement'
    uci set firewall.allow_icmpv6_input.limit='1000/sec'
    uci set firewall.allow_icmpv6_input.family='ipv6'
    uci set firewall.allow_icmpv6_input.target='ACCEPT'

    uci set firewall.allow_icmpv6_forward='rule'
    uci set firewall.allow_icmpv6_forward.name='Allow-ICMPv6-Forward'
    uci set firewall.allow_icmpv6_forward.dest='*'
    uci set firewall.allow_icmpv6_forward.proto='icmp'
    uci set firewall.allow_icmpv6_forward.icmp_type='echo-request destination-unreachable packet-too-big time-exceeded bad-header unknown-header-type'
    uci set firewall.allow_icmpv6_forward.limit='1000/sec'
    uci set firewall.allow_icmpv6_forward.family='ipv6'
    uci set firewall.allow_icmpv6_forward.target='ACCEPT'

    uci set firewall.allow_dhcpv6='rule'
    uci set firewall.allow_dhcpv6.name='Allow-DHCPv6'
    uci set firewall.allow_dhcpv6.proto='udp'
    uci set firewall.allow_dhcpv6.src_ip='fc00::/6'
    uci set firewall.allow_dhcpv6.src_port='547'
    uci set firewall.allow_dhcpv6.dest_port='546'
    uci set firewall.allow_dhcpv6.family='ipv6'
    uci set firewall.allow_dhcpv6.target='ACCEPT'
end

### SECTION 5: ZONE CONFIGURATION ###
echo "$blue""Configuring firewall zones...""$reset"

# First verify that all required networks exist
set required_networks core guest iot meta nexus nodes wireguard wan
set missing_networks

for net in $required_networks
    if not uci -q get "network.$net" > /dev/null
        set -a missing_networks $net
    end
end

# If networks are missing, warn but don't abort - we'll create zones anyway
if test (count $missing_networks) -gt 0
    echo "$yellow""WARNING: The following networks referenced in firewall aren't defined yet:""$reset"
    echo "$yellow""(string join ", " $missing_networks)""$reset"
    echo "$yellow""Proceeding with firewall configuration anyway.""$reset"
end  # Added missing end statement for this if block

# Core Zone
echo "$green""Adding Core Zone (trusted network)...""$reset"
uci set firewall.core='zone'
uci set firewall.core.name='core'
uci set firewall.core.network='core'
uci set firewall.core.input='ACCEPT'
uci set firewall.core.output='ACCEPT'
uci set firewall.core.forward='REJECT'

# Guest Zone
echo "$green""Adding Guest Zone (untrusted network)...""$reset"
uci set firewall.guest='zone'
uci set firewall.guest.name='guest'
uci set firewall.guest.network='guest'
uci set firewall.guest.input='DROP'
uci set firewall.guest.output='ACCEPT'
uci set firewall.guest.forward='REJECT'

# IoT Zone
echo "$green""Adding IoT Zone...""$reset"
uci set firewall.iot='zone'
uci set firewall.iot.name='iot'
uci set firewall.iot.network='iot'
uci set firewall.iot.input='DROP'
uci set firewall.iot.output='DROP'
uci set firewall.iot.forward='REJECT'

# Meta Zone
echo "$green""Adding Meta Zone...""$reset"
uci set firewall.meta='zone'
uci set firewall.meta.name='meta'
uci set firewall.meta.network='meta'
uci set firewall.meta.input='DROP'
uci set firewall.meta.output='DROP'
uci set firewall.meta.forward='REJECT'

# Nexus Zone
echo "$green""Adding Nexus Zone...""$reset"
uci set firewall.nexus='zone'
uci set firewall.nexus.name='nexus'
uci set firewall.nexus.network='nexus'
uci set firewall.nexus.input='DROP'
uci set firewall.nexus.output='ACCEPT'
uci set firewall.nexus.forward='REJECT'

# Nodes Zone
echo "$green""Adding Nodes Zone...""$reset"
uci set firewall.nodes='zone'
uci set firewall.nodes.name='nodes'
uci set firewall.nodes.network='nodes'
uci set firewall.nodes.input='DROP'
uci set firewall.nodes.output='ACCEPT'
uci set firewall.nodes.forward='REJECT'

# WireGuard Zone
echo "$green""Adding WireGuard Zone...""$reset"
uci set firewall.wireguard='zone'
uci set firewall.wireguard.name='wireguard'
uci set firewall.wireguard.network='wireguard'
uci set firewall.wireguard.input='DROP'
uci set firewall.wireguard.output='ACCEPT'
uci set firewall.wireguard.forward='REJECT'

# WAN Zone
echo "$blue""Configuring WAN zone...""$reset"
uci set firewall.wan_zone='zone'
uci set firewall.wan_zone.name='wan'

# Only include wan6 in networks list if IPv6 is enabled
if test "$ENABLE_WAN6" = "true"
    echo "$yellow""IPv6 is enabled, including wan6 in WAN zone""$reset"
    uci set firewall.wan_zone.network='wan wan6'
else
    echo "$yellow""IPv6 is not enabled, only including wan in WAN zone""$reset"
    uci set firewall.wan_zone.network='wan'
end

uci set firewall.wan_zone.input="$WAN_POLICY_IN"
uci set firewall.wan_zone.output="$WAN_POLICY_OUT"
uci set firewall.wan_zone.forward="$WAN_POLICY_FORWARD"
uci set firewall.wan_zone.masq='1'

# Add a high-priority traffic rule to enforce the DROP policy on WAN input
echo "$green""Adding traffic rule to enforce DROP policy on WAN input...""$reset"
uci set firewall.enforce_wan_input='rule'
uci set firewall.enforce_wan_input.name='Enforce-WAN-Input-Policy'
uci set firewall.enforce_wan_input.src='wan'
uci set firewall.enforce_wan_input.dest='*'
uci set firewall.enforce_wan_input.proto='all'
uci set firewall.enforce_wan_input.target='DROP'
uci set firewall.enforce_wan_input.priority='5'  # High priority, but lower than anti-lockout
uci set firewall.enforce_wan_input.enabled='1'

### SECTION 6: ZONE FORWARDING RULES ###
echo "$blue""Configuring zone forwarding rules...""$reset"

# Core to WAN
echo "$green""Adding forwarding from Core to WAN...""$reset"
uci set firewall.forward_core_to_wan='forwarding'
uci set firewall.forward_core_to_wan.src='core'
uci set firewall.forward_core_to_wan.dest='wan'

# Guest to WAN
echo "$green""Adding forwarding from Guest to WAN...""$reset"
uci set firewall.forward_guest_to_wan='forwarding'
uci set firewall.forward_guest_to_wan.src='guest'
uci set firewall.forward_guest_to_wan.dest='wan'

# Nexus to WAN
echo "$green""Adding forwarding from Nexus to WAN...""$reset"
uci set firewall.forward_nexus_to_wan='forwarding'
uci set firewall.forward_nexus_to_wan.src='nexus'
uci set firewall.forward_nexus_to_wan.dest='wan'

# Nodes to WAN
echo "$green""Adding forwarding from Nodes to WAN...""$reset"
uci set firewall.forward_nodes_to_wan='forwarding'
uci set firewall.forward_nodes_to_wan.src='nodes'
uci set firewall.forward_nodes_to_wan.dest='wan'

# Core to all other internal zones
echo "$green""Adding forwarding from Core to other internal zones...""$reset"
for zone in nexus nodes meta iot
    uci set firewall."forward_core_to_$zone"='forwarding'
    uci set firewall."forward_core_to_$zone".src='core'
    uci set firewall."forward_core_to_$zone".dest="$zone"
end

# Allow forwarding from WireGuard to LAN zones
echo "$green""Adding forwarding from WireGuard to LAN zones...""$reset"
uci set firewall.forward_wg_to_lan='forwarding'
uci set firewall.forward_wg_to_lan.src='wireguard'
uci set firewall.forward_wg_to_lan.dest='core nexus nodes meta iot guest'

# ADD THIS: Allow forwarding from WireGuard to WAN
echo "$green""Adding forwarding from WireGuard to WAN...""$reset"
uci set firewall.forward_wg_to_wan='forwarding'
uci set firewall.forward_wg_to_wan.src='wireguard'
uci set firewall.forward_wg_to_wan.dest='wan'

### SECTION 7: DNS ACCESS RULES ###
echo "$blue""Configuring DNS rules...""$reset"

# Add per-zone rules for DNS access and redirection
for zone in core nexus nodes meta iot guest wireguard  # Added wireguard to the loop
  echo "$green""Creating DNS rules for zone $zone...""$reset"
  
  # Allow DNS access
  uci set firewall."allow_dns_$zone"='rule'
  uci set firewall."allow_dns_$zone".name="Allow-DNS-$zone"
  uci set firewall."allow_dns_$zone".src="$zone"
  uci set firewall."allow_dns_$zone".proto='tcp udp'
  uci set firewall."allow_dns_$zone".dest_port='53'
  uci set firewall."allow_dns_$zone".target='ACCEPT'
  uci set firewall."allow_dns_$zone".enabled='1'
  
  # DNS UDP redirection
  uci set firewall."redirect_dns_udp_$zone"='redirect'
  uci set firewall."redirect_dns_udp_$zone".name="Redirect-DNS-UDP-$zone"
  uci set firewall."redirect_dns_udp_$zone".src="$zone"
  uci set firewall."redirect_dns_udp_$zone".proto='udp'
  uci set firewall."redirect_dns_udp_$zone".src_dport='53'
  uci set firewall."redirect_dns_udp_$zone".dest_port='53'
  uci set firewall."redirect_dns_udp_$zone".target='DNAT'

  # DNS TCP redirection
  uci set firewall."redirect_dns_tcp_$zone"='redirect'
  uci set firewall."redirect_dns_tcp_$zone".name="Redirect-DNS-TCP-$zone"
  uci set firewall."redirect_dns_tcp_$zone".src="$zone"
  uci set firewall."redirect_dns_tcp_$zone".proto='tcp'
  uci set firewall."redirect_dns_tcp_$zone".src_dport='53'
  uci set firewall."redirect_dns_tcp_$zone".dest_port='53'
  uci set firewall."redirect_dns_tcp_$zone".target='DNAT'
end

# Block direct external DNS
echo "$blue""Blocking direct external DNS access...""$reset"
uci set firewall.block_external_dns='rule'
uci set firewall.block_external_dns.name='Block-External-DNS'
uci set firewall.block_external_dns.src='*'
uci set firewall.block_external_dns.dest='wan'
uci set firewall.block_external_dns.proto='tcp udp'
uci set firewall.block_external_dns.dest_port='53'
uci set firewall.block_external_dns.target='REJECT'
uci set firewall.block_external_dns.enabled='1'

### SECTION 8: WIREGUARD PORT FORWARDING ###
echo "$blue""Configuring WireGuard port forwarding...""$reset"

# Port Forward: WAN -> WireGuard
echo "$green""Adding port forward from WAN to WireGuard...""$reset"
uci set firewall.port_forward_wan_to_wg='redirect'
uci set firewall.port_forward_wan_to_wg.name='PortForwardWANtoWG'
uci set firewall.port_forward_wan_to_wg.src='wan'
uci set firewall.port_forward_wan_to_wg.src_dport='52018'
uci set firewall.port_forward_wan_to_wg.dest='wireguard'
uci set firewall.port_forward_wan_to_wg.dest_ip="$WIREGUARD_IP"
uci set firewall.port_forward_wan_to_wg.proto='udp'
uci set firewall.port_forward_wan_to_wg.enabled='1'

### SECTION 9: VERIFICATION ###
echo "$purple""Verifying firewall configuration...""$reset"

# List critical rules to verify they exist
echo "$blue""Critical anti-lockout rules:""$reset"
uci show firewall.allow_established
uci show firewall.mgmt_access
uci show firewall.ssh_from_core
uci show firewall.ssh_from_wireguard

echo "$blue""Critical DHCP rules:""$reset"
uci show firewall.allow_dhcp
uci show firewall.allow_dhcp_renew

echo "$blue""Critical zone configurations:""$reset"
uci show firewall.core
uci show firewall.wan_zone
uci show firewall.wireguard

# Finished
echo "$green""Firewall configuration completed successfully. Changes will be applied during final commit.""$reset"