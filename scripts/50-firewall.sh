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

# Find and preserve any default rules we want to keep (by rule name)
echo "Preserving default system rules..."
set DEFAULT_RULES
set MULTICAST_RULES

for rule in (uci show firewall | grep '@rule' | cut -d. -f2 | cut -d= -f1)
  set rule_name (uci get firewall.$rule.name 2>/dev/null)
  if test "$rule_name" = "Allow-DHCP-Renew"; or test "$rule_name" = "Allow-Ping"; or test "$rule_name" = "Allow-DHCPv6"; or test "$rule_name" = "Allow-ICMPv6-Input"; or test "$rule_name" = "Allow-ICMPv6-Forward"
    echo "Preserving default rule: $rule_name"
    set -a DEFAULT_RULES $rule
  else if test "$rule_name" = "Allow-IGMP"; or test "$rule_name" = "Allow-MLD"
    echo "Preserving multicast rule: $rule_name (will be disabled)"
    set -a MULTICAST_RULES $rule
  end
end

# Remove any existing Allow-IPSec-ESP and Allow-ISAKMP rules specifically
echo "Removing any existing Allow-IPSec-ESP and Allow-ISAKMP rules..."
for rule in (uci show firewall | grep -E "name='Allow-IPSec-ESP'|name='Allow-ISAKMP'" | cut -d. -f2 | cut -d= -f1)
  echo "Deleting firewall rule: $rule"
  uci delete firewall.$rule
  echo "Notice: Firewall rule $rule has been deleted."
end

# Clear redirects, rules, forwarding, and zones
echo "Cleaning up firewall configuration..."
while uci delete firewall.@redirect[0] 2>/dev/null
  echo "Deleted firewall.@redirect[0]."
end

while uci delete firewall.@rule[0] 2>/dev/null
  echo "Deleted firewall.@rule[0]."
end

while uci delete firewall.@forwarding[0] 2>/dev/null
  echo "Deleted firewall.@forwarding[0]."
end

while uci delete firewall.@zone[0] 2>/dev/null
  echo "Deleted firewall.@zone[0]."
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
uci add firewall zone
uci set firewall.@zone[-1]='zone'
uci set firewall.@zone[-1].name='wan'
uci set firewall.@zone[-1].network='wan wan6'
uci set firewall.@zone[-1].input="$WAN_POLICY_IN"
uci set firewall.@zone[-1].output="$WAN_POLICY_OUT"
uci set firewall.@zone[-1].forward="$WAN_POLICY_FORWARD"
uci set firewall.@zone[-1].masq='1'  # Keep NAT enabled

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

#########################################
# SECTION 2.1: DISABLED SPECIAL RULES
#########################################

echo "Configuring special disabled rules (VPN and multicast)..."

# Add disabled IPSec-ESP and ISAKMP rules for core
echo "Adding disabled IPSec/VPN rules..."
uci add firewall rule
uci set firewall.@rule[-1]='rule'
uci set firewall.@rule[-1].name='Allow-IPSec-ESP'
uci set firewall.@rule[-1].src='wan'
uci set firewall.@rule[-1].dest='core'
uci set firewall.@rule[-1].proto='esp'
uci set firewall.@rule[-1].target='ACCEPT'
uci set firewall.@rule[-1].enabled='0'

uci add firewall rule
uci set firewall.@rule[-1]='rule'
uci set firewall.@rule[-1].name='Allow-ISAKMP'
uci set firewall.@rule[-1].src='wan'
uci set firewall.@rule[-1].dest='core'
uci set firewall.@rule[-1].dest_port='500'
uci set firewall.@rule[-1].proto='udp'
uci set firewall.@rule[-1].target='ACCEPT'
uci set firewall.@rule[-1].enabled='0'

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
  uci add firewall rule
  uci set firewall.@rule[-1]='rule'
  uci set firewall.@rule[-1].name='Allow-IGMP'
  uci set firewall.@rule[-1].src='wan'
  uci set firewall.@rule[-1].proto='igmp'
  uci set firewall.@rule[-1].target='ACCEPT'
  uci set firewall.@rule[-1].enabled='0'
  
  # Allow-MLD rule
  uci add firewall rule
  uci set firewall.@rule[-1]='rule'
  uci set firewall.@rule[-1].name='Allow-MLD'
  uci set firewall.@rule[-1].src='wan'
  uci set firewall.@rule[-1].family='ipv6'
  uci set firewall.@rule[-1].proto='icmp'
  uci set firewall.@rule[-1].icmp_type='130/0'
  uci set firewall.@rule[-1].target='ACCEPT'
  uci set firewall.@rule[-1].enabled='0'
end

####################################
# SECTION 3: ZONE FORWARDING RULES
####################################

echo "Configuring zone forwarding rules..."

# Core to WAN (Internet access for ClosedWrt network)
echo "Adding forwarding from Core to WAN..."
uci add firewall forwarding
uci set firewall.@forwarding[-1]='forwarding'
uci set firewall.@forwarding[-1].src='core'
uci set firewall.@forwarding[-1].dest='wan'

# Guest to WAN (Internet access for OpenWrt network)
echo "Adding forwarding from Guest to WAN for internet access..."
uci add firewall forwarding
uci set firewall.@forwarding[-1]='forwarding'
uci set firewall.@forwarding[-1].src='guest'
uci set firewall.@forwarding[-1].dest='wan'

# Allow all zones to get DHCP, even without internet access
echo "Adding DHCP access rules for all other zones (without internet access)..."

# For IoT network
echo "Adding DHCP access for IoT network..."
uci add firewall rule
uci set firewall.@rule[-1]='rule'
uci set firewall.@rule[-1].name='Allow-DHCP-IoT'
uci set firewall.@rule[-1].src='iot'
uci set firewall.@rule[-1].proto='udp'
uci set firewall.@rule[-1].dest_port='67 68'
uci set firewall.@rule[-1].target='ACCEPT'

# For Meta network
echo "Adding DHCP access for Meta network..."
uci add firewall rule
uci set firewall.@rule[-1]='rule'
uci set firewall.@rule[-1].name='Allow-DHCP-Meta'
uci set firewall.@rule[-1].src='meta'
uci set firewall.@rule[-1].proto='udp'
uci set firewall.@rule[-1].dest_port='67 68'
uci set firewall.@rule[-1].target='ACCEPT'

# For Nexus network
echo "Adding DHCP access for Nexus network..."
uci add firewall rule
uci set firewall.@rule[-1]='rule'
uci set firewall.@rule[-1].name='Allow-DHCP-Nexus'
uci set firewall.@rule[-1].src='nexus'
uci set firewall.@rule[-1].proto='udp'
uci set firewall.@rule[-1].dest_port='67 68'
uci set firewall.@rule[-1].target='ACCEPT'

# For Nodes network
echo "Adding DHCP access for Nodes network..."
uci add firewall rule
uci set firewall.@rule[-1]='rule'
uci set firewall.@rule[-1].name='Allow-DHCP-Nodes'
uci set firewall.@rule[-1].src='nodes'
uci set firewall.@rule[-1].proto='udp'
uci set firewall.@rule[-1].dest_port='67 68'
uci set firewall.@rule[-1].target='ACCEPT'

######################################
# SECTION 4: DNS CONFIGURATION RULES
######################################

echo "Configuring DNS rules and enforcement..."

# Allow DNS for guest network specifically
echo "Adding DNS access for guest network..."
uci add firewall rule
uci set firewall.@rule[-1]='rule'
uci set firewall.@rule[-1].name='Allow-DNS-Guest'
uci set firewall.@rule[-1].src='guest'
uci set firewall.@rule[-1].proto='tcp udp'
uci set firewall.@rule[-1].dest_port='53'
uci set firewall.@rule[-1].target='ACCEPT'
uci set firewall.@rule[-1].enabled='1'

# DNS enforcement - force all clients to use router DNS
echo "Adding DNS enforcement rules to redirect all DNS queries to router..."

# Add per-zone rules for DNS redirection
for zone in core nexus nodes meta iot guest
  echo "Creating NAT rules to redirect DNS traffic to router for zone $zone..."
  
  # DNS UDP Rule
  uci add firewall redirect
  uci set firewall.@redirect[-1]='redirect'
  uci set firewall.@redirect[-1].name="Redirect-DNS-UDP-$zone"
  uci set firewall.@redirect[-1].src="$zone"
  uci set firewall.@redirect[-1].proto='udp'
  uci set firewall.@redirect[-1].src_dport='53'
  uci set firewall.@redirect[-1].dest_port='53'
  uci set firewall.@redirect[-1].target='DNAT'

  # DNS TCP Rule
  uci add firewall redirect
  uci set firewall.@redirect[-1]='redirect'
  uci set firewall.@redirect[-1].name="Redirect-DNS-TCP-$zone"
  uci set firewall.@redirect[-1].src="$zone"
  uci set firewall.@redirect[-1].proto='tcp'
  uci set firewall.@redirect[-1].src_dport='53'
  uci set firewall.@redirect[-1].dest_port='53'
  uci set firewall.@redirect[-1].target='DNAT'
end

# Block direct external DNS
echo "Blocking direct external DNS access except from router..."
uci add firewall rule
uci set firewall.@rule[-1]='rule'
uci set firewall.@rule[-1].name='Block-External-DNS'
uci set firewall.@rule[-1].src='*'
uci set firewall.@rule[-1].dest='wan'
uci set firewall.@rule[-1].proto='tcp udp'
uci set firewall.@rule[-1].dest_port='53'
uci set firewall.@rule[-1].target='REJECT'
uci set firewall.@rule[-1].enabled='1'

#########################################
# SECTION 5: SERVICE & PROTOCOL RULES
#########################################

echo "Configuring service and protocol specific rules..."

# Guest DHCP rule - Allow guest network to get DHCP addresses
echo "Adding rule to allow guest network to acquire DHCP addresses..."
uci add firewall rule
uci set firewall.@rule[-1]='rule'
uci set firewall.@rule[-1].name='Allow-DHCP-Guest'
uci set firewall.@rule[-1].src='guest'
uci set firewall.@rule[-1].proto='udp'
uci set firewall.@rule[-1].dest_port='67 68'
uci set firewall.@rule[-1].target='ACCEPT'
uci set firewall.@rule[-1].enabled='1'

#######################################
# SECTION 6: PORT FORWARDING RULES
#######################################

echo "Configuring port forwarding rules..."

# Port Forward: WAN -> WireGuard
echo "Adding port forward from WAN to WireGuard ($WIREGUARD_IP)..."
uci add firewall redirect
uci set firewall.@redirect[-1]='redirect'
uci set firewall.@redirect[-1].name='PortForwardWANtoWG'
uci set firewall.@redirect[-1].src='wan'
uci set firewall.@redirect[-1].src_dport='52018'
uci set firewall.@redirect[-1].dest='wireguard'
uci set firewall.@redirect[-1].dest_ip="$WIREGUARD_IP"
uci set firewall.@redirect[-1].proto='udp'
uci set firewall.@redirect[-1].enabled='0'

#############################
# SECTION 7: FINALIZE
#############################

# Commit all changes to apply the entire firewall configuration at once
echo "Finalizing and committing all firewall changes..."
uci commit firewall
echo "Firewall configuration completed successfully."