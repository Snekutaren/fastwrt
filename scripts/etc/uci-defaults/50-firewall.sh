#!/usr/bin/fish
# FastWrt firewall configuration script - Implementation using fish shell
# Fish shell is the default shell in FastWrt and should be used for all scripts

# Source common color definitions
source "$PROFILE_DIR/colors.fish"

# Ensure the script runs from its own directory
cd $BASE_DIR
echo "$blue""Current working directory: ""$reset"(pwd)

# Log the start of the script
echo "$purple""Starting firewall configuration...""$reset"

### SECTION 1: DEFINE CONSTANTS AND MANAGEMENT IPs ###
# Define management IPs that should always have access
set -g ALLOWED_CORE_MGMT_IPS "10.0.0.60 10.0.0.61"
set -g ALLOWED_WG_MGMT_IPS "10.255.0.2 10.255.0.3"
echo "$blue""Core management IPs: $ALLOWED_CORE_MGMT_IPS""$reset"
echo "$blue""WireGuard management IPs: $ALLOWED_WG_MGMT_IPS""$reset"

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

# Rule 3: Allow SSH access from core network (only from specific IPs)
uci set firewall.ssh_from_core='rule'
uci set firewall.ssh_from_core.name='SSH-from-Core'
uci set firewall.ssh_from_core.src='core'
uci set firewall.ssh_from_core.src_ip="$ALLOWED_CORE_MGMT_IPS"
uci set firewall.ssh_from_core.proto='tcp'
uci set firewall.ssh_from_core.dest_port='6622'
uci set firewall.ssh_from_core.target='ACCEPT'
uci set firewall.ssh_from_core.priority='3'
uci set firewall.ssh_from_core.enabled='1'
uci set firewall.ssh_from_core.family='any' # Ensure IPv4 and IPv6

# Rule 4: Allow SSH access from WireGuard (only from specific IP)
uci set firewall.ssh_from_wireguard='rule'
uci set firewall.ssh_from_wireguard.name='SSH-from-WireGuard'
uci set firewall.ssh_from_wireguard.src='wireguard'
uci set firewall.ssh_from_wireguard.src_ip="$ALLOWED_WG_MGMT_IPS"
uci set firewall.ssh_from_wireguard.proto='tcp'
uci set firewall.ssh_from_wireguard.dest_port='6622'
uci set firewall.ssh_from_wireguard.target='ACCEPT'
uci set firewall.ssh_from_wireguard.priority='3'
uci set firewall.ssh_from_wireguard.enabled='1'
uci set firewall.ssh_from_wireguard.family='any' # Ensure IPv4 and IPv6

# Rule 5: Enable web access from core network (optional: restrict to management IPs if desired)
uci set firewall.web_from_core='rule'
uci set firewall.web_from_core.name='Web-from-Core'
uci set firewall.web_from_core.src='core'
uci set firewall.web_from_core.src_ip="$ALLOWED_CORE_MGMT_IPS"
uci set firewall.web_from_core.proto='tcp'
uci set firewall.web_from_core.dest_port='80 443'
uci set firewall.web_from_core.target='ACCEPT'
uci set firewall.web_from_core.priority='4'
uci set firewall.web_from_core.enabled='1'
uci set firewall.web_from_core.family='any' # Ensure IPv4 and IPv6

# Rule 6: Enable web access from WireGuard for specific IPs
uci set firewall.web_from_wireguard='rule'
uci set firewall.web_from_wireguard.name='Web-from-WireGuard'
uci set firewall.web_from_wireguard.src='wireguard'
uci set firewall.web_from_wireguard.src_ip="$ALLOWED_WG_MGMT_IPS"
uci set firewall.web_from_wireguard.proto='tcp'
uci set firewall.web_from_wireguard.dest_port='80 443'
uci set firewall.web_from_wireguard.target='ACCEPT'
uci set firewall.web_from_wireguard.priority='4'
uci set firewall.web_from_wireguard.enabled='1'
uci set firewall.web_from_wireguard.family='any' # Ensure IPv4 and IPv6

# --- Internal Access Rules for Management Hosts ---

# Allow HTTP/HTTPS to x570-truenas-vm (10.0.20.101) from core and wireguard
uci set firewall.allow_truenas_web='rule'
uci set firewall.allow_truenas_web.name='Allow-Truenas-Web'
uci set firewall.allow_truenas_web.src='core wireguard'
uci set firewall.allow_truenas_web.src_ip="$ALLOWED_CORE_MGMT_IPS $ALLOWED_WG_MGMT_IPS"
uci set firewall.allow_truenas_web.dest='nodes'
uci set firewall.allow_truenas_web.dest_ip='10.0.20.101'
uci set firewall.allow_truenas_web.proto='tcp'
uci set firewall.allow_truenas_web.dest_port='80 443'
uci set firewall.allow_truenas_web.target='ACCEPT'
uci set firewall.allow_truenas_web.enabled='1'

# Allow SSH to x570-truenas-vm (10.0.20.101) from core and wireguard
uci set firewall.allow_truenas_ssh='rule'
uci set firewall.allow_truenas_ssh.name='Allow-Truenas-SSH'
uci set firewall.allow_truenas_ssh.src='core wireguard'
uci set firewall.allow_truenas_ssh.src_ip="$ALLOWED_CORE_MGMT_IPS $ALLOWED_WG_MGMT_IPS"
uci set firewall.allow_truenas_ssh.dest='nodes'
uci set firewall.allow_truenas_ssh.dest_ip='10.0.20.101'
uci set firewall.allow_truenas_ssh.proto='tcp'
uci set firewall.allow_truenas_ssh.dest_port='6622'
uci set firewall.allow_truenas_ssh.target='ACCEPT'
uci set firewall.allow_truenas_ssh.enabled='1'

# Allow SSH to x570-machine-vm (10.0.20.100) from core and wireguard
uci set firewall.allow_machine_ssh='rule'
uci set firewall.allow_machine_ssh.name='Allow-Machine-SSH'
uci set firewall.allow_machine_ssh.src='core wireguard'
uci set firewall.allow_machine_ssh.src_ip="$ALLOWED_CORE_MGMT_IPS $ALLOWED_WG_MGMT_IPS"
uci set firewall.allow_machine_ssh.dest='nodes'
uci set firewall.allow_machine_ssh.dest_ip='10.0.20.100'
uci set firewall.allow_machine_ssh.proto='tcp'
uci set firewall.allow_machine_ssh.dest_port='6622'
uci set firewall.allow_machine_ssh.target='ACCEPT'
uci set firewall.allow_machine_ssh.enabled='1'

# Allow Proxmox web (8006) and SSH (6622) to x570-proxmox (10.0.10.10) from core and wireguard
uci set firewall.allow_proxmox_web='rule'
uci set firewall.allow_proxmox_web.name='Allow-Proxmox-Web'
uci set firewall.allow_proxmox_web.src='core wireguard'
uci set firewall.allow_proxmox_web.src_ip="$ALLOWED_CORE_MGMT_IPS $ALLOWED_WG_MGMT_IPS"
uci set firewall.allow_proxmox_web.dest='nexus'
uci set firewall.allow_proxmox_web.dest_ip='10.0.10.10'
uci set firewall.allow_proxmox_web.proto='tcp'
uci set firewall.allow_proxmox_web.dest_port='8006'
uci set firewall.allow_proxmox_web.target='ACCEPT'
uci set firewall.allow_proxmox_web.enabled='1'

uci set firewall.allow_proxmox_ssh='rule'
uci set firewall.allow_proxmox_ssh.name='Allow-Proxmox-SSH'
uci set firewall.allow_proxmox_ssh.src='core wireguard'
uci set firewall.allow_proxmox_ssh.src_ip="$ALLOWED_CORE_MGMT_IPS $ALLOWED_WG_MGMT_IPS"
uci set firewall.allow_proxmox_ssh.dest='nexus'
uci set firewall.allow_proxmox_ssh.dest_ip='10.0.10.10'
uci set firewall.allow_proxmox_ssh.proto='tcp'
uci set firewall.allow_proxmox_ssh.dest_port='6622'
uci set firewall.allow_proxmox_ssh.target='ACCEPT'
uci set firewall.allow_proxmox_ssh.enabled='1'

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

# Add IPv6 rules for WAN6 regardless of ENABLE_WAN6
echo "$green""Creating WAN6 (IPv6) rules...""$reset"
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

### SECTION 5: ZONE CONFIGURATION ###
echo "$blue""Configuring firewall zones...""$reset"

# Define all internal zones and their properties in an array
set -l ZONES core guest iot meta nexus nodes wireguard
set -l ZONE_NETWORKS core guest iot meta nexus nodes wireguard
set -l ZONE_INPUT   ACCEPT REJECT REJECT REJECT REJECT REJECT REJECT
set -l ZONE_OUTPUT  ACCEPT ACCEPT DROP DROP ACCEPT ACCEPT ACCEPT
set -l ZONE_FORWARD REJECT REJECT REJECT REJECT REJECT REJECT REJECT

# First verify that all required networks exist
set required_networks $ZONE_NETWORKS wan
set missing_networks

for net in $required_networks
    if not uci -q get "network.$net" > /dev/null
        set -a missing_networks $net
    end
end

if test (count $missing_networks) -gt 0
    echo "$yellow""WARNING: The following networks referenced in firewall aren't defined yet:""$reset"
    echo "$yellow""(string join ", " $missing_networks)""$reset"
    echo "$yellow""Proceeding with firewall configuration anyway.""$reset"
end

# Create each zone using a loop
for i in (seq 1 (count $ZONES))
    set zone $ZONES[$i]
    set net $ZONE_NETWORKS[$i]
    set input $ZONE_INPUT[$i]
    set output $ZONE_OUTPUT[$i]
    set forward $ZONE_FORWARD[$i]
    echo "$green""Adding $zone zone...""$reset"
    uci set firewall.$zone='zone'
    uci set firewall.$zone.name="$zone"
    uci set firewall.$zone.network="$net"
    uci set firewall.$zone.input="$input"
    uci set firewall.$zone.output="$output"
    uci set firewall.$zone.forward="$forward"
end

# WAN Zone (handled separately for IPv6 and policy override)
echo "$blue""Configuring WAN zone...""$reset"

# Force WAN_POLICY_IN to DROP for security, regardless of environment or LuCI
if test "$WAN_POLICY_IN" != "DROP"
    echo "$red""CRITICAL SAFETY OVERRIDE: WAN input policy was set to $WAN_POLICY_IN, forcing to DROP""$reset"
    set WAN_POLICY_IN "DROP"
end

# CRITICAL SAFETY CHECK: WAN output policy must ALWAYS be ACCEPT to maintain internet connectivity
if test "$WAN_POLICY_OUT" != "ACCEPT"
    echo "$red""CRITICAL SAFETY OVERRIDE: WAN output policy was set to $WAN_POLICY_OUT, forcing to ACCEPT""$reset"
    echo "$red""Setting WAN output policy to anything but ACCEPT will break internet connectivity!""$reset"
    set WAN_POLICY_OUT "ACCEPT"
end

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

# Double check WAN_POLICY_OUT one more time right before setting it
set WAN_POLICY_OUT "ACCEPT"
echo "$green""Setting WAN zone output policy to ACCEPT to ensure internet connectivity""$reset"

uci set firewall.wan_zone.input="$WAN_POLICY_IN"
uci set firewall.wan_zone.output="$WAN_POLICY_OUT"
uci set firewall.wan_zone.forward="$WAN_POLICY_FORWARD"
uci set firewall.wan_zone.masq='1'

# Enforce DROP on all WAN input, regardless of zone policy or future changes
echo "$red""Enforcing DROP on all WAN input with highest-priority rule...""$reset"
uci set firewall.enforce_wan_input='rule'
uci set firewall.enforce_wan_input.name='Enforce-WAN-Input-Policy'
uci set firewall.enforce_wan_input.src='wan'
uci set firewall.enforce_wan_input.dest='*'
uci set firewall.enforce_wan_input.proto='all'
uci set firewall.enforce_wan_input.target='DROP'
uci set firewall.enforce_wan_input.priority='1'  # Absolute highest priority
uci set firewall.enforce_wan_input.enabled='1'

### SECTION 6: ZONE FORWARDING RULES ###
echo "$blue""Configuring zone forwarding rules...""$reset"

# Define forwarding rules as an array of src:dest
set -l FORWARDINGS \
    "core:wan" \
    "guest:wan" \
    "nexus:wan" \
    "nodes:wan"

# Add core to all other internal zones
for zone in nexus nodes meta iot
    set -a FORWARDINGS "core:$zone"
end

# Add wireguard to LAN zones and WAN (split into individual entries)
for zone in core nexus nodes guest
    set -a FORWARDINGS "wireguard:$zone"
end
set -a FORWARDINGS "wireguard:wan"  # This adds the first forwarding rule

# Create forwarding rules using a loop
for fwd in $FORWARDINGS
    set src (string split ":" $fwd)[1]
    set dest (string split ":" $fwd)[2]
    echo "$green""Adding forwarding from $src to $dest...""$reset"
    set fwd_name (string join "_" forward $src to $dest)
    uci set firewall.$fwd_name='forwarding'
    uci set firewall.$fwd_name.src="$src"
    uci set firewall.$fwd_name.dest="$dest"
end

### SECTION 7: DNS ACCESS RULES ###
echo "$blue""Configuring DNS rules...""$reset"

# Only use actual firewall zones (not rules) for DNS rules
set all_zones
for zone in (uci show firewall | grep "\.name=" | cut -d. -f2 | cut -d= -f1)
    # Only include if this is a zone section (not a rule, redirect, or forwarding)
    set section_type (uci -q get firewall.$zone 2>/dev/null)
    if test "$section_type" = "zone"
        set zone_name (uci -q get firewall.$zone.name)
        if test "$zone_name" != "wan"; and test "$zone_name" != "wan_zone"
            set -a all_zones $zone_name
        end
    end
end

# Remove duplicates (in case of multiple sections with same name)
set unique_zones (printf "%s\n" $all_zones | sort -u)

# Add per-zone rules for DNS access and redirection (excluding wan/wan_zone)
for zone in $unique_zones
    echo "$green""Creating DNS rules for zone $zone...""$reset"

    # Allow DNS access
    uci set firewall.allow_dns_$zone='rule'
    uci set firewall.allow_dns_$zone.name="Allow-DNS-$zone"
    uci set firewall.allow_dns_$zone.src="$zone"
    uci set firewall.allow_dns_$zone.proto='tcp udp'
    uci set firewall.allow_dns_$zone.dest_port='53'
    uci set firewall.allow_dns_$zone.target='ACCEPT'
    uci set firewall.allow_dns_$zone.enabled='1'

    # DNS UDP redirection
    uci set firewall.redirect_dns_udp_$zone='redirect'
    uci set firewall.redirect_dns_udp_$zone.name="Redirect-DNS-UDP-$zone"
    uci set firewall.redirect_dns_udp_$zone.src="$zone"
    uci set firewall.redirect_dns_udp_$zone.proto='udp'
    uci set firewall.redirect_dns_udp_$zone.src_dport='53'
    uci set firewall.redirect_dns_udp_$zone.dest_port='53'
    uci set firewall.redirect_dns_udp_$zone.target='DNAT'

    # DNS TCP redirection
    uci set firewall.redirect_dns_tcp_$zone='redirect'
    uci set firewall.redirect_dns_tcp_$zone.name="Redirect-DNS-TCP-$zone"
    uci set firewall.redirect_dns_tcp_$zone.src="$zone"
    uci set firewall.redirect_dns_tcp_$zone.proto='tcp'
    uci set firewall.redirect_dns_tcp_$zone.src_dport='53'
    uci set firewall.redirect_dns_tcp_$zone.dest_port='53'
    uci set firewall.redirect_dns_tcp_$zone.target='DNAT'
end

# FIX DNS ISSUES:
# Replace the block_external_dns rule with a better implementation
# that still blocks clients but allows the router itself to reach DNS
echo "$blue""Configuring DNS access rules...""$reset"

# Remove the old rule that blocks all external DNS
uci -q delete firewall.block_external_dns

# Add a rule to allow the router to use external DNS
uci set firewall.router_dns_out='rule'
uci set firewall.router_dns_out.name='Allow-Router-DNS'
uci set firewall.router_dns_out.src='*'  # From any source 
uci set firewall.router_dns_out.dest='wan'
uci set firewall.router_dns_out.proto='tcp udp'
uci set firewall.router_dns_out.dest_port='53'
uci set firewall.router_dns_out.target='ACCEPT'
uci set firewall.router_dns_out.priority='30'
uci set firewall.router_dns_out.enabled='1'

# Block direct client access to external DNS (keep enforcing local DNS)
# But this time we use src_ip=!192.168.1.1 to exempt the router itself
uci set firewall.block_client_dns='rule'
uci set firewall.block_client_dns.name='Redirect-Client-DNS'
uci set firewall.block_client_dns.src='*'
uci set firewall.block_client_dns.src_ip='!10.0.0.1 !10.0.10.1 !10.0.20.1 !10.0.70.1 !10.0.80.1 !192.168.90.1'  # Exempt router IPs
uci set firewall.block_client_dns.dest='wan'
uci set firewall.block_client_dns.proto='tcp udp'
uci set firewall.block_client_dns.dest_port='53'
uci set firewall.block_client_dns.target='REJECT'
uci set firewall.block_client_dns.enabled='1'


# CRITICAL SECURITY FIX: Block external access to web interface
echo "$red""CRITICAL: Adding highest priority rules to block external access to router web interface...""$reset"

# Block HTTP from WAN (port 80) with ABSOLUTE HIGHEST priority
uci set firewall.block_http_from_wan='rule'
uci set firewall.block_http_from_wan.name='Block-HTTP-From-WAN'
uci set firewall.block_http_from_wan.src='wan'
uci set firewall.block_http_from_wan.proto='tcp'
uci set firewall.block_http_from_wan.dest_port='80'
uci set firewall.block_http_from_wan.target='DROP'
uci set firewall.block_http_from_wan.enabled='1'
uci set firewall.block_http_from_wan.priority='1'  # HIGHEST priority to override EVERYTHING

# Block HTTPS from WAN (port 443) with ABSOLUTE HIGHEST priority
uci set firewall.block_https_from_wan='rule'
uci set firewall.block_https_from_wan.name='Block-HTTPS-From-WAN'
uci set firewall.block_https_from_wan.src='wan'
uci set firewall.block_https_from_wan.proto='tcp'
uci set firewall.block_https_from_wan.dest_port='443'
uci set firewall.block_https_from_wan.target='DROP'
uci set firewall.block_https_from_wan.enabled='1'
uci set firewall.block_https_from_wan.priority='1'  # HIGHEST priority to override EVERYTHING

### SECTION 8: WIREGUARD PORT FORWARDING ###
echo "$blue""Configuring WireGuard firewall rules...""$reset"

# CRITICAL: Ensure WireGuard port is open in firewall
echo "$blue""Configuring WireGuard firewall rules...""$reset"
if not uci -q get firewall.allow_wireguard_port > /dev/null
    # Remove unnecessary port forwarding - WireGuard doesn't need it
    # Port forwarding (DNAT) is for redirecting traffic to internal services
    # WireGuard already listens directly on its interface
    
    echo "$blue""Adding explicit allow rule for WireGuard port...""$reset"
    uci set firewall.allow_wireguard_port='rule'
    uci set firewall.allow_wireguard_port.name='Allow-WireGuard-Port'
    uci set firewall.allow_wireguard_port.src='wan'
    uci set firewall.allow_wireguard_port.dest_port='52018'
    uci set firewall.allow_wireguard_port.proto='udp'
    uci set firewall.allow_wireguard_port.target='ACCEPT'
    uci set firewall.allow_wireguard_port.enabled='1'
    uci set firewall.allow_wireguard_port.priority='10'  # Higher priority
    
    echo "$blue""Configuring WireGuard traffic to use WAN zone masquerading""$reset"
end

### SECTION 9: VERIFICATION ###
echo "$purple""Verifying firewall configuration...""$reset"

# List critical rules to verify they exist
echo "$blue""Critical anti-lockout rules:""$reset"
uci show firewall.allow_established

echo "$blue""Critical SSH rules:""$reset"
uci show firewall.ssh_from_core
uci show firewall.ssh_from_wireguard

echo "$blue""Critical web access rules:""$reset"
uci show firewall.web_from_core
uci show firewall.web_from_wireguard

echo "$blue""Critical management host rules:""$reset"
uci show firewall.allow_truenas_web
uci show firewall.allow_truenas_ssh
uci show firewall.allow_machine_ssh
uci show firewall.allow_proxmox_web
uci show firewall.allow_proxmox_ssh

echo "$blue""Critical DHCP/DNS rules:""$reset"
uci show firewall.allow_dhcp
uci show firewall.allow_dhcp_renew
uci show firewall.allow_dns_core
uci show firewall.allow_dns_nexus
uci show firewall.allow_dns_nodes
uci show firewall.allow_dns_meta
uci show firewall.allow_dns_iot
uci show firewall.allow_dns_guest
uci show firewall.allow_dns_wireguard
uci show firewall.router_dns_out
uci show firewall.block_client_dns

echo "$blue""Critical WAN protection rules:""$reset"
uci show firewall.block_http_from_wan
uci show firewall.block_https_from_wan
uci show firewall.enforce_wan_input

echo "$blue""Critical WireGuard port rule:""$reset"
uci show firewall.allow_wireguard_port

echo "$blue""Critical zone configurations:""$reset"
for zone in $ZONES
    uci show firewall.$zone
end
uci show firewall.wan_zone

# Finished
echo "$green""Firewall configuration completed successfully. Changes will be applied during final commit.""$reset"