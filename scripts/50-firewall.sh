#!/bin/bash
# Using bash for enhanced array support and other features
set -e  # Exit on any error
# Ensure the script runs from its own directory
cd "$BASE_DIR"
echo "Current working directory: $(pwd)"

# Log the start of the script
echo "Starting firewall configuration..."

#############################################
# SECTION 1: CLEANUP & INITIAL CONFIGURATION
#############################################

# Find and preserve any default rules we want to keep (by rule name)
# Using bash arrays for cleaner code
echo "Preserving default system rules..."
DEFAULT_RULES=()
MULTICAST_RULES=()

for rule in $(uci show firewall | grep '@rule' | cut -d. -f2 | cut -d= -f1); do
  rule_name=$(uci get firewall.$rule.name 2>/dev/null)
  if [ "$rule_name" = "Allow-DHCP-Renew" ] || [ "$rule_name" = "Allow-Ping" ] || [ "$rule_name" = "Allow-DHCPv6" ] || [ "$rule_name" = "Allow-ICMPv6-Input" ] || [ "$rule_name" = "Allow-ICMPv6-Forward" ]; then
    echo "Preserving default rule: $rule_name"
    DEFAULT_RULES+=("$rule")
  elif [ "$rule_name" = "Allow-IGMP" ] || [ "$rule_name" = "Allow-MLD" ]; then
    echo "Preserving multicast rule: $rule_name (will be disabled)"
    MULTICAST_RULES+=("$rule")
  fi
done

# Remove any existing Allow-IPSec-ESP and Allow-ISAKMP rules specifically
echo "Removing any existing Allow-IPSec-ESP and Allow-ISAKMP rules..."
for rule in $(uci show firewall | grep -E "name='Allow-IPSec-ESP'|name='Allow-ISAKMP'" | cut -d. -f2 | cut -d= -f1); do
  echo "Deleting firewall rule: $rule"
  uci delete firewall.$rule
  echo "Notice: Firewall rule $rule has been deleted."
done

# Clear redirects, rules, forwarding, and zones (preserving defaults is handled after)
echo "Cleaning up firewall configuration..."
while uci delete firewall.@redirect[0] 2>/dev/null; do
  echo "Deleted firewall.@redirect[0]."
done

while uci delete firewall.@rule[0] 2>/dev/null; do
  echo "Deleted firewall.@rule[0]."
done

while uci delete firewall.@forwarding[0] 2>/dev/null; do
  echo "Deleted firewall.@forwarding[0]."
done

while uci delete firewall.@zone[0] 2>/dev/null; do
  echo "Deleted firewall.@zone[0]."
done

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

# Core Zone (Uses Core Zone Policy: $CORE_POLICY_IN/$CORE_POLICY_OUT/$CORE_POLICY_FORWARD)
echo "Adding Core Zone (Input: $CORE_POLICY_IN, Output: $CORE_POLICY_OUT, Forward: $CORE_POLICY_FORWARD)..."
uci set firewall.core=zone
uci set firewall.core.name='core'
uci set firewall.core.network='core'
uci set firewall.core.input="${CORE_POLICY_IN:-ACCEPT}"
uci set firewall.core.output="${CORE_POLICY_OUT:-ACCEPT}"
uci set firewall.core.forward="${CORE_POLICY_FORWARD:-REJECT}"

# Nexus Zone (Uses Other Zones Policy)
echo "Adding Nexus Zone (Input: $OTHER_ZONES_POLICY_IN, Output: $OTHER_ZONES_POLICY_OUT, Forward: $OTHER_ZONES_POLICY_FORWARD)..."
uci set firewall.nexus=zone
uci set firewall.nexus.name='nexus'
uci set firewall.nexus.network='nexus'
uci set firewall.nexus.input="${OTHER_ZONES_POLICY_IN:-DROP}"
uci set firewall.nexus.output="${OTHER_ZONES_POLICY_OUT:-DROP}"
uci set firewall.nexus.forward="${OTHER_ZONES_POLICY_FORWARD:-DROP}"

# Nodes Zone (Uses Other Zones Policy)
echo "Adding Nodes Zone (Input: $OTHER_ZONES_POLICY_IN, Output: $OTHER_ZONES_POLICY_OUT, Forward: $OTHER_ZONES_POLICY_FORWARD)..."
uci set firewall.nodes=zone
uci set firewall.nodes.name='nodes'
uci set firewall.nodes.network='nodes'
uci set firewall.nodes.input="${OTHER_ZONES_POLICY_IN:-DROP}"
uci set firewall.nodes.output="${OTHER_ZONES_POLICY_OUT:-DROP}"
uci set firewall.nodes.forward="${OTHER_ZONES_POLICY_FORWARD:-DROP}"

# Meta Zone (Uses Other Zones Policy)
echo "Adding meta Zone (Input: $OTHER_ZONES_POLICY_IN, Output: $OTHER_ZONES_POLICY_OUT, Forward: $OTHER_ZONES_POLICY_FORWARD)..."
uci set firewall.meta=zone
uci set firewall.meta.name='meta'
uci set firewall.meta.network='meta'
uci set firewall.meta.input="${OTHER_ZONES_POLICY_IN:-DROP}"
uci set firewall.meta.output="${OTHER_ZONES_POLICY_OUT:-DROP}"
uci set firewall.meta.forward="${OTHER_ZONES_POLICY_FORWARD:-DROP}"

# IoT Zone (Uses Other Zones Policy)
echo "Adding IoT Zone (Input: $OTHER_ZONES_POLICY_IN, Output: $OTHER_ZONES_POLICY_OUT, Forward: $OTHER_ZONES_POLICY_FORWARD)..."
uci set firewall.Iot=zone
uci set firewall.Iot.name='Iot'
uci set firewall.Iot.network='iot'
uci set firewall.Iot.input="${OTHER_ZONES_POLICY_IN:-DROP}"
uci set firewall.Iot.output="${OTHER_ZONES_POLICY_OUT:-DROP}"
uci set firewall.Iot.forward="${OTHER_ZONES_POLICY_FORWARD:-DROP}"

# Guest Zone (Uses Other Zones Policy)
echo "Adding guest Zone (Input: $OTHER_ZONES_POLICY_IN, Output: $OTHER_ZONES_POLICY_OUT, Forward: $OTHER_ZONES_POLICY_FORWARD)..."
uci set firewall.guest=zone
uci set firewall.guest.name='guest'
uci set firewall.guest.network='guest'
uci set firewall.guest.input="${OTHER_ZONES_POLICY_IN:-DROP}"
uci set firewall.guest.output="${OTHER_ZONES_POLICY_OUT:-DROP}"
uci set firewall.guest.forward="${OTHER_ZONES_POLICY_FORWARD:-DROP}"

# WireGuard Zone (Uses Other Zones Policy)
echo "Adding WireGuard Zone (Input: $OTHER_ZONES_POLICY_IN, Output: $OTHER_ZONES_POLICY_OUT, Forward: $OTHER_ZONES_POLICY_FORWARD)..."
uci set firewall.wireguard=zone
uci set firewall.wireguard.name='wireguard'
uci set firewall.wireguard.network='wireguard'
uci set firewall.wireguard.input="${OTHER_ZONES_POLICY_IN:-DROP}"
uci set firewall.wireguard.output="${OTHER_ZONES_POLICY_OUT:-DROP}"
uci set firewall.wireguard.forward="${OTHER_ZONES_POLICY_FORWARD:-DROP}"

# WAN Zone (Uses WAN Zone Policy)
echo "Adding WAN Zone (Input: $WAN_POLICY_IN, Output: $WAN_POLICY_OUT, Forward: $WAN_POLICY_FORWARD)..."
uci set firewall.wan=zone
uci set firewall.wan.name='wan'
uci set firewall.wan.network='wan wan6'
uci set firewall.wan.input="${WAN_POLICY_IN:-DROP}"
uci set firewall.wan.output="${WAN_POLICY_OUT:-ACCEPT}"
uci set firewall.wan.forward="${WAN_POLICY_FORWARD:-DROP}"
uci set firewall.wan.masq='1'  # Keep NAT enabled

# Re-add default system rules that we preserved
echo "Re-adding preserved default system rules..."
for rule in "${DEFAULT_RULES[@]}"; do
  rule_name=$(uci get firewall.$rule.name 2>/dev/null)
  echo "Re-adding default rule: $rule_name"
  uci add firewall rule
  
  # Copy all properties from the preserved rule
  for prop in $(uci show firewall.$rule | cut -d= -f1); do
    prop_name=$(echo "$prop" | cut -d. -f3)
    prop_value=$(uci get $prop 2>/dev/null)
    uci set firewall.@rule[-1].$prop_name="$prop_value"
  done
done

#########################################
# SECTION 2.1: DISABLED SPECIAL RULES
#########################################

echo "Configuring special disabled rules (VPN and multicast)..."

# Add disabled IPSec-ESP and ISAKMP rules for core
echo "Adding disabled IPSec/VPN rules..."
uci add firewall rule
uci set firewall.@rule[-1].name='Allow-IPSec-ESP'
uci set firewall.@rule[-1].src='wan'
uci set firewall.@rule[-1].dest='core'
uci set firewall.@rule[-1].proto='esp'
uci set firewall.@rule[-1].target='ACCEPT'
uci set firewall.@rule[-1].enabled='0'

uci add firewall rule
uci set firewall.@rule[-1].name='Allow-ISAKMP'
uci set firewall.@rule[-1].src='wan'
uci set firewall.@rule[-1].dest='core'
uci set firewall.@rule[-1].dest_port='500'
uci set firewall.@rule[-1].proto='udp'
uci set firewall.@rule[-1].target='ACCEPT'
uci set firewall.@rule[-1].enabled='0'

# Re-add multicast rules that we preserved but keep them disabled
echo "Re-adding preserved multicast rules (disabled)..."
for rule in "${MULTICAST_RULES[@]}"; do
  rule_name=$(uci get firewall.$rule.name 2>/dev/null)
  echo "Re-adding multicast rule: $rule_name"
  uci add firewall rule
  
  # Copy all properties from the preserved rule
  for prop in $(uci show firewall.$rule | cut -d= -f1); do
    prop_name=$(echo "$prop" | cut -d. -f3)
    prop_value=$(uci get $prop 2>/dev/null)
    uci set firewall.@rule[-1].$prop_name="$prop_value"
  done
  
  # Explicitly disable the rule
  echo "Disabling multicast rule: $rule_name"
  uci set firewall.@rule[-1].enabled='0'
done

# Clean up temporary files when done
rm -rf "$TMP_DIR"

####################################
# SECTION 3: ZONE FORWARDING RULES
####################################

echo "Configuring zone forwarding rules..."

# Core to WAN (Internet access for Core)
echo "Adding forwarding from Core to WAN..."
uci add firewall forwarding
uci set firewall.@forwarding[-1].src='core'
uci set firewall.@forwarding[-1].dest='wan'

# Guest to WAN (Internet access for Guest)
echo "Adding forwarding from Guest to WAN for internet access..."
uci add firewall forwarding
uci set firewall.@forwarding[-1].src='guest'
uci set firewall.@forwarding[-1].dest='wan'

# Note: Guest access to internal networks is already blocked by default
# as no forwarding rules exist between guest and internal zones.
# This can be managed through the LuCI interface if needed.

######################################
# SECTION 4: DNS CONFIGURATION RULES
######################################

echo "Configuring DNS rules and enforcement..."

# Allow DNS for guest network specifically
echo "Adding DNS access for guest network..."
uci add firewall rule
uci set firewall.@rule[-1].name='Allow-DNS-Guest'
uci set firewall.@rule[-1].src='guest'
uci set firewall.@rule[-1].proto='tcp udp'
uci set firewall.@rule[-1].dest_port='53'
uci set firewall.@rule[-1].target='ACCEPT'
uci set firewall.@rule[-1].enabled='1'

# DNS enforcement - force all clients to use router DNS
echo "Adding DNS enforcement rules to redirect all DNS queries to router..."

# Add per-zone rules for DNS redirection
for zone in core nexus nodes meta iot guest; do
  echo "Creating NAT rules to redirect DNS traffic to router for zone $zone..."
  # DNS UDP Rule
  uci add firewall redirect
  uci set firewall.@redirect[-1].name="Redirect-DNS-UDP-$zone"
  uci set firewall.@redirect[-1].src="$zone"
  uci set firewall.@redirect[-1].proto='udp'
  uci set firewall.@redirect[-1].src_dport='53'
  uci set firewall.@redirect[-1].dest_port='53'
  uci set firewall.@redirect[-1].target='DNAT'

  # DNS TCP Rule
  uci add firewall redirect
  uci set firewall.@redirect[-1].name="Redirect-DNS-TCP-$zone"
  uci set firewall.@redirect[-1].src="$zone"
  uci set firewall.@redirect[-1].proto='tcp'
  uci set firewall.@redirect[-1].src_dport='53'
  uci set firewall.@redirect[-1].dest_port='53'
  uci set firewall.@redirect[-1].target='DNAT'
done

# Block direct external DNS (prevents DNS over HTTPS/TLS circumvention)
echo "Blocking direct external DNS access except from router..."
uci add firewall rule
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