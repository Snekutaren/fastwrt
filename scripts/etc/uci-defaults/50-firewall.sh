#!/usr/bin/fish
# FastWrt firewall configuration script - Pure fish implementation

# Ensure the script runs from its own directory
cd $BASE_DIR
echo "Current working directory: "(pwd)

# Log the start of the script
echo "Starting firewall configuration..."

#############################################
# SECTION 1: CLEANUP & INITIAL CONFIGURATION
#############################################

# Log all existing rules before cleanup for debugging
echo "Existing rules before cleanup:"
uci show firewall | grep '@rule' | sort

# Find and preserve any default rules we want to keep (by rule name)
echo "Preserving default system rules..."
set preserved_rules
set DEFAULT_RULES

# Check for existing named rules to preserve
for rule in (uci show firewall | grep '@rule' | cut -d. -f2 | cut -d= -f1)
  set rule_name (uci -q get firewall.$rule.name)
  # Only preserve essential system rules, not our custom ones
  if string match -q "Allow-DHCP-Renew" "$rule_name"; or \
     string match -q "Allow-Ping" "$rule_name"; or \
     string match -q "Allow-DHCPv6" "$rule_name"; or \
     string match -q "Allow-ICMPv6-Input" "$rule_name"; or \
     string match -q "Allow-ICMPv6-Forward" "$rule_name"
     
    echo "Preserving essential system rule: $rule_name"
    # Store the rule name and section to be restored later
    set -a preserved_rules "$rule_name"
    # Add to DEFAULT_RULES for later re-adding
    set -a DEFAULT_RULES "$rule"
    # Create a variable with the rule details for restoration
    set -g "preserved_rule_$rule_name" (uci show firewall.$rule | tr '\n' '|')
  else
    echo "Will remove rule: $rule ($rule_name)"
  end
end

# Clear all firewall configuration completely
echo "Cleaning up firewall configuration..."

# Clear redirects
while uci -q delete firewall.@redirect[0] > /dev/null
  echo "Deleted firewall.@redirect[0]"
end

# Clear rules
while uci -q delete firewall.@rule[0] > /dev/null
  echo "Deleted firewall.@rule[0]"
end

# Clear forwarding
while uci -q delete firewall.@forwarding[0] > /dev/null
  echo "Deleted firewall.@forwarding[0]"
end

# Clear zones (except defaults)
while uci -q delete firewall.@zone[0] > /dev/null
  echo "Deleted firewall.@zone[0]"
end

# Firewall Defaults (Drop All)
echo "Setting global firewall defaults..."
uci set firewall.@defaults[0].input='DROP'
uci set firewall.@defaults[0].output='DROP'
uci set firewall.@defaults[0].forward='DROP'
uci set firewall.@defaults[0].syn_flood='1'
uci set firewall.@defaults[0].drop_invalid='1'
uci set firewall.@defaults[0].flow_offloading='1'
uci set firewall.@defaults[0].flow_offloading_hw='1'

# Re-add the essential system rules we preserved with proper names
echo "Restoring preserved system rules..."
for rule_name in $preserved_rules
  echo "Re-adding system rule: $rule_name"
  
  # Create new rule with proper name as section identifier (sanitized for UCI)
  set rule_section (string replace -a "-" "_" $rule_name | string lower)
  uci set firewall.$rule_section='rule'
  uci set firewall.$rule_section.name="$rule_name"
  
  # Get the stored rule properties
  set rule_config (eval "echo \$preserved_rule_$rule_name")
  
  # Parse and restore all rule properties
  for prop in (string split "|" $rule_config)
    if test -n "$prop"
      # Extract the property name (after the last dot)
      set prop_parts (string match -r '\.([^=]+)=' "$prop")
      set prop_name $prop_parts[2]
      
      # Skip if prop_name is empty or 'name' (we already set it)
      if test -n "$prop_name" -a "$prop_name" != "name"
        # Extract the value from the property (after the equals sign)
        set prop_value (string match -r '=(.*)' "$prop")
        set prop_value (string trim -c "'" "$prop_value[2]")
        
        # Set the property
        uci set firewall.$rule_section.$prop_name="$prop_value"
        echo "  Setting $prop_name=$prop_value"
      end
    end
  end
  
  # Ensure mandatory fields are set
  if test -z (uci -q get firewall.$rule_section.target)
    uci set firewall.$rule_section.target='ACCEPT'
  end
end

#################################
# SECTION 2: ZONE CONFIGURATION
#################################

echo "Adding firewall zones..."

# Core Zone
echo "Adding Core Zone (Input: $CORE_POLICY_IN, Output: $CORE_POLICY_OUT, Forward: $CORE_POLICY_FORWARD)..."
uci set firewall.core='zone'
uci set firewall.core.name='core'
uci set firewall.core.network='core'
uci set firewall.core.input="$CORE_POLICY_IN"
uci set firewall.core.output="$CORE_POLICY_OUT"
uci set firewall.core.forward="$CORE_POLICY_FORWARD"

# Nexus Zone
echo "Adding Nexus Zone..."
uci set firewall.nexus='zone'
uci set firewall.nexus.name='nexus'
uci set firewall.nexus.network='nexus'
uci set firewall.nexus.input="$OTHER_ZONES_POLICY_IN"
uci set firewall.nexus.output="$OTHER_ZONES_POLICY_OUT"
uci set firewall.nexus.forward="$OTHER_ZONES_POLICY_FORWARD"

# Nodes Zone
echo "Adding Nodes Zone..."
uci set firewall.nodes='zone'
uci set firewall.nodes.name='nodes'
uci set firewall.nodes.network='nodes'
uci set firewall.nodes.input="$OTHER_ZONES_POLICY_IN"
uci set firewall.nodes.output="$OTHER_ZONES_POLICY_OUT"
uci set firewall.nodes.forward="$OTHER_ZONES_POLICY_FORWARD"

# Meta Zone
echo "Adding meta Zone..."
uci set firewall.meta='zone'
uci set firewall.meta.name='meta'
uci set firewall.meta.network='meta'
uci set firewall.meta.input="$OTHER_ZONES_POLICY_IN"
uci set firewall.meta.output="$OTHER_ZONES_POLICY_OUT"
uci set firewall.meta.forward="$OTHER_ZONES_POLICY_FORWARD"

# IoT Zone
echo "Adding IoT Zone..."
uci set firewall.iot='zone'
uci set firewall.iot.name='iot'
uci set firewall.iot.network='iot'
uci set firewall.iot.input="$OTHER_ZONES_POLICY_IN"
uci set firewall.iot.output="$OTHER_ZONES_POLICY_OUT"
uci set firewall.iot.forward="$OTHER_ZONES_POLICY_FORWARD"

# Guest Zone
echo "Adding guest Zone..."
uci set firewall.guest='zone'
uci set firewall.guest.name='guest'
uci set firewall.guest.network='guest'
uci set firewall.guest.input="$OTHER_ZONES_POLICY_IN"
uci set firewall.guest.output="$OTHER_ZONES_POLICY_OUT"
uci set firewall.guest.forward="$OTHER_ZONES_POLICY_FORWARD"

# WireGuard Zone
echo "Adding WireGuard Zone..."
uci set firewall.wireguard='zone'
uci set firewall.wireguard.name='wireguard'
uci set firewall.wireguard.network='wireguard'
uci set firewall.wireguard.input="$OTHER_ZONES_POLICY_IN"
uci set firewall.wireguard.output="$OTHER_ZONES_POLICY_OUT"
uci set firewall.wireguard.forward="$OTHER_ZONES_POLICY_FORWARD"

# WAN Zone
echo "Adding WAN Zone..."
uci set firewall.wan_zone='zone'
uci set firewall.wan_zone.name='wan'
uci set firewall.wan_zone.network='wan wan6'
uci set firewall.wan_zone.input="$WAN_POLICY_IN"
uci set firewall.wan_zone.output="$WAN_POLICY_OUT"
uci set firewall.wan_zone.forward="$WAN_POLICY_FORWARD"
uci set firewall.wan_zone.masq='1'  # Keep NAT enabled

# Re-add default system rules that we preserved
echo "Re-adding preserved default system rules..."
for rule in $DEFAULT_RULES
  set rule_name (uci get firewall.$rule.name 2>/dev/null)
  echo "Re-adding default rule: $rule_name"
  uci add firewall rule
  uci set firewall.@rule[-1]='rule'
  
  # Copy all properties from the preserved rule
  for prop in (uci show firewall.$rule | cut -d= -f1)
    set prop_name (echo "$prop" | cut -d. -f3)
    set prop_value (uci get $prop 2>/dev/null)
    uci set firewall.@rule[-1].$prop_name "$prop_value"
  end
end

##################################
# SECTION 2.1: SSH ACCESS RULES
##################################

echo "Configuring SSH firewall access rules..."

# Allow SSH access only from core network
uci set firewall.ssh_access_core='rule'
uci set firewall.ssh_access_core.name='SSH-from-core'
uci set firewall.ssh_access_core.src='core'
uci set firewall.ssh_access_core.proto='tcp'
uci set firewall.ssh_access_core.dest_port='6622'
uci set firewall.ssh_access_core.target='ACCEPT'

# Allow SSH access from WireGuard VPN
uci set firewall.ssh_access_wireguard='rule'
uci set firewall.ssh_access_wireguard.name='SSH-from-wireguard'
uci set firewall.ssh_access_wireguard.src='wireguard'
uci set firewall.ssh_access_wireguard.proto='tcp'
uci set firewall.ssh_access_wireguard.dest_port='6622'
uci set firewall.ssh_access_wireguard.target='ACCEPT'

# Explicitly block SSH access from WAN for clarity
uci set firewall.ssh_block_wan='rule'
uci set firewall.ssh_block_wan.name='SSH-block-wan'
uci set firewall.ssh_block_wan.src='wan'
uci set firewall.ssh_block_wan.proto='tcp'
uci set firewall.ssh_block_wan.dest_port='6622'
uci set firewall.ssh_block_wan.target='REJECT'
uci set firewall.ssh_block_wan.enabled='1'

# SSH rate limiting rule (moved from secure_ssh.sh)
uci set firewall.ssh_limit='rule'
uci set firewall.ssh_limit.name='SSH-Limit'
uci set firewall.ssh_limit.src='wan'
uci set firewall.ssh_limit.proto='tcp'
uci set firewall.ssh_limit.dest_port='6622'
uci set firewall.ssh_limit.limit='10/minute'
uci set firewall.ssh_limit.target='ACCEPT'
uci set firewall.ssh_limit.enabled='0'  # Disabled by default, enable in secure_ssh.sh

# Enhanced SSH protection with connection tracking (moved from secure_ssh.sh)
uci set firewall.ssh_protect='rule'
uci set firewall.ssh_protect.name='SSH-Protection'
uci set firewall.ssh_protect.src='wan'
uci set firewall.ssh_protect.proto='tcp'
uci set firewall.ssh_protect.dest_port='6622'
uci set firewall.ssh_protect.target='DROP'
uci set firewall.ssh_protect.limit='1/second'
uci set firewall.ssh_protect.connbytes='60'
uci set firewall.ssh_protect.connbytes_mode='connbytes'
uci set firewall.ssh_protect.connbytes_dir='original'
uci set firewall.ssh_protect.enabled='0'  # Disabled by default, enable in secure_ssh.sh

#########################################
# SECTION 2.2: DISABLED SPECIAL RULES
#########################################

echo "Configuring special disabled rules (VPN and multicast)..."

# Add disabled IPSec-ESP and ISAKMP rules for core
echo "Adding disabled IPSec/VPN rules..."
uci set firewall.allow_ipsec_esp='rule'
uci set firewall.allow_ipsec_esp.name='Allow-IPSec-ESP'
uci set firewall.allow_ipsec_esp.src='wan'
uci set firewall.allow_ipsec_esp.dest='core'
uci set firewall.allow_ipsec_esp.proto='esp'
uci set firewall.allow_ipsec_esp.target='ACCEPT'
uci set firewall.allow_ipsec_esp.enabled='0'

uci set firewall.allow_isakmp='rule'
uci set firewall.allow_isakmp.name='Allow-ISAKMP'
uci set firewall.allow_isakmp.src='wan'
uci set firewall.allow_isakmp.dest='core'
uci set firewall.allow_isakmp.dest_port='500'
uci set firewall.allow_isakmp.proto='udp'
uci set firewall.allow_isakmp.target='ACCEPT'
uci set firewall.allow_isakmp.enabled='0'

# Re-add multicast rules that we preserved but keep them disabled
echo "Re-adding preserved multicast rules (disabled)..."
if test (count $MULTICAST_RULES) -gt 0
  # Debug: Print the multicast rules we're about to add
  echo "Found "(count $MULTICAST_RULES)" multicast rules to restore:"
  for rule in $MULTICAST_RULES
    echo "- $rule"
  end
  
  for rule in $MULTICAST_RULES
    set rule_name (uci get firewall.$rule.name 2>/dev/null)
    echo "Re-adding multicast rule: $rule_name"
    uci add firewall rule
    uci set firewall.@rule[-1]='rule'
    
    # Copy all properties from the preserved rule
    for prop in (uci show firewall.$rule | cut -d= -f1)
      set prop_name (echo "$prop" | cut -d. -f3)
      set prop_value (uci get $prop 2>/dev/null)
      echo "  Setting property $prop_name to $prop_value"
      uci set firewall.@rule[-1].$prop_name="$prop_value"
    end
    
    # Explicitly disable the rule
    echo "Disabling multicast rule: $rule_name"
    uci set firewall.@rule[-1].enabled='0'
  end
else
  echo "No multicast rules found to restore."
  
  # Add default multicast rules if none were preserved
  echo "Creating default multicast rules (disabled)..."

  # Allow-IGMP rule
  uci set firewall.allow_igmp='rule'
  uci set firewall.allow_igmp.name='Allow-IGMP'
  uci set firewall.allow_igmp.src='wan'
  uci set firewall.allow_igmp.proto='igmp'
  uci set firewall.allow_igmp.target='ACCEPT'
  uci set firewall.allow_igmp.enabled='0'

  # Allow-MLD rule
  uci set firewall.allow_mld='rule'
  uci set firewall.allow_mld.name='Allow-MLD'
  uci set firewall.allow_mld.src='wan'
  uci set firewall.allow_mld.family='ipv6'
  uci set firewall.allow_mld.proto='icmp'
  uci set firewall.allow_mld.icmp_type='130/0'
  uci set firewall.allow_mld.target='ACCEPT'
  uci set firewall.allow_mld.enabled='0'
end

####################################
# SECTION 3: ZONE FORWARDING RULES
####################################

echo "Configuring zone forwarding rules..."

# Core to WAN (Internet access for ClosedWrt network)
echo "Adding forwarding from Core to WAN..."
uci set firewall.forward_core_to_wan='forwarding'
uci set firewall.forward_core_to_wan.src='core'
uci set firewall.forward_core_to_wan.dest='wan'

# Guest to WAN (Internet access for OpenWrt network)
echo "Adding forwarding from Guest to WAN for internet access..."
uci set firewall.forward_guest_to_wan='forwarding'
uci set firewall.forward_guest_to_wan.src='guest'
uci set firewall.forward_guest_to_wan.dest='wan'

# Allow all zones to get DHCP, even without internet access
echo "Adding DHCP access rules for all other zones (without internet access)..."

# For IoT network
echo "Adding DHCP access for IoT network..."
uci set firewall.allow_dhcp_iot='rule'
uci set firewall.allow_dhcp_iot.name='Allow-DHCP-IoT'
uci set firewall.allow_dhcp_iot.src='iot'
uci set firewall.allow_dhcp_iot.proto='udp'
uci set firewall.allow_dhcp_iot.dest_port='67 68'
uci set firewall.allow_dhcp_iot.target='ACCEPT'

# For Meta network
echo "Adding DHCP access for Meta network..."
uci set firewall.allow_dhcp_meta='rule'
uci set firewall.allow_dhcp_meta.name='Allow-DHCP-Meta'
uci set firewall.allow_dhcp_meta.src='meta'
uci set firewall.allow_dhcp_meta.proto='udp'
uci set firewall.allow_dhcp_meta.dest_port='67 68'
uci set firewall.allow_dhcp_meta.target='ACCEPT'

# For Nexus network
echo "Adding DHCP access for Nexus network..."
uci set firewall.allow_dhcp_nexus='rule'
uci set firewall.allow_dhcp_nexus.name='Allow-DHCP-Nexus'
uci set firewall.allow_dhcp_nexus.src='nexus'
uci set firewall.allow_dhcp_nexus.proto='udp'
uci set firewall.allow_dhcp_nexus.dest_port='67 68'
uci set firewall.allow_dhcp_nexus.target='ACCEPT'

# For Nodes network
echo "Adding DHCP access for Nodes network..."
uci set firewall.allow_dhcp_nodes='rule'
uci set firewall.allow_dhcp_nodes.name='Allow-DHCP-Nodes'
uci set firewall.allow_dhcp_nodes.src='nodes'
uci set firewall.allow_dhcp_nodes.proto='udp'
uci set firewall.allow_dhcp_nodes.dest_port='67 68'
uci set firewall.allow_dhcp_nodes.target='ACCEPT'

######################################
# SECTION 4: DNS CONFIGURATION RULES
######################################

echo "Configuring DNS rules and enforcement..."

# Allow DNS for guest network specifically
echo "Adding DNS access for guest network..."
uci set firewall.allow_dns_guest='rule'
uci set firewall.allow_dns_guest.name='Allow-DNS-Guest'
uci set firewall.allow_dns_guest.src='guest'
uci set firewall.allow_dns_guest.proto='tcp udp'
uci set firewall.allow_dns_guest.dest_port='53'
uci set firewall.allow_dns_guest.target='ACCEPT'
uci set firewall.allow_dns_guest.enabled='1'

# DNS enforcement - force all clients to use router DNS
echo "Adding DNS enforcement rules to redirect all DNS queries to router..."

# Add per-zone rules for DNS redirection
for zone in core nexus nodes meta iot guest
  echo "Creating NAT rules to redirect DNS traffic to router for zone $zone..."
  
  # DNS UDP Rule with named section to prevent duplicates
  set redirect_name_udp "redirect_dns_udp_$zone"
  uci set firewall.$redirect_name_udp='redirect'
  uci set firewall.$redirect_name_udp.name="Redirect-DNS-UDP-$zone"
  uci set firewall.$redirect_name_udp.src="$zone"
  uci set firewall.$redirect_name_udp.proto='udp'
  uci set firewall.$redirect_name_udp.src_dport='53'
  uci set firewall.$redirect_name_udp.dest_port='53'
  uci set firewall.$redirect_name_udp.target='DNAT'

  # DNS TCP Rule with named section to prevent duplicates
  set redirect_name_tcp "redirect_dns_tcp_$zone"
  uci set firewall.$redirect_name_tcp='redirect'
  uci set firewall.$redirect_name_tcp.name="Redirect-DNS-TCP-$zone"
  uci set firewall.$redirect_name_tcp.src="$zone"
  uci set firewall.$redirect_name_tcp.proto='tcp'
  uci set firewall.$redirect_name_tcp.src_dport='53'
  uci set firewall.$redirect_name_tcp.dest_port='53'
  uci set firewall.$redirect_name_tcp.target='DNAT'
end

# Block direct external DNS with named section to prevent duplicates
echo "Blocking direct external DNS access except from router..."
uci set firewall.block_external_dns='rule'
uci set firewall.block_external_dns.name='Block-External-DNS'
uci set firewall.block_external_dns.src='*'
uci set firewall.block_external_dns.dest='wan'
uci set firewall.block_external_dns.proto='tcp udp'
uci set firewall.block_external_dns.dest_port='53'
uci set firewall.block_external_dns.target='REJECT'
uci set firewall.block_external_dns.enabled='1'

#########################################
# SECTION 5: SERVICE & PROTOCOL RULES
#########################################

echo "Configuring service and protocol specific rules..."

# Guest DHCP rule - Allow guest network to get DHCP addresses
echo "Adding rule to allow guest network to acquire DHCP addresses..."
uci set firewall.allow_dhcp_guest='rule'
uci set firewall.allow_dhcp_guest.name='Allow-DHCP-Guest'
uci set firewall.allow_dhcp_guest.src='guest'
uci set firewall.allow_dhcp_guest.proto='udp'
uci set firewall.allow_dhcp_guest.dest_port='67 68'
uci set firewall.allow_dhcp_guest.target='ACCEPT'
uci set firewall.allow_dhcp_guest.enabled='1'

#######################################
# SECTION 6: PORT FORWARDING RULES
#######################################

echo "Configuring port forwarding rules..."

# Port Forward: WAN -> WireGuard
echo "Adding port forward from WAN to WireGuard ($WIREGUARD_IP)..."
uci set firewall.port_forward_wan_to_wg='redirect'
uci set firewall.port_forward_wan_to_wg.name='PortForwardWANtoWG'
uci set firewall.port_forward_wan_to_wg.src='wan'
uci set firewall.port_forward_wan_to_wg.src_dport='52018'
uci set firewall.port_forward_wan_to_wg.dest='wireguard'
uci set firewall.port_forward_wan_to_wg.dest_ip="$WIREGUARD_IP"
uci set firewall.port_forward_wan_to_wg.proto='udp'
uci set firewall.port_forward_wan_to_wg.enabled='0'

#############################
# SECTION 7: FINALIZE
#############################

# Log completion of script
# Note: UCI commits are handled in 98-commit.sh
echo "Firewall configuration completed successfully. Changes will be applied during final commit."