#!/bin/sh

set -e  # Exit on any error

# Log the start of the script
echo "Starting firewall configuration..."

# Disable firewall rules containing IPSec-ESP or ISAKMP
echo "Disabling firewall rules containing IPSec-ESP or ISAKMP..."
for rule in $(uci show firewall | grep -E 'IPSec-ESP|ISAKMP' | cut -d. -f2 | cut -d= -f1); do
  echo "Disabling firewall rule: $rule"
  uci set firewall.$rule.enabled='0'
  echo "Notice: Firewall rule $rule has been disabled."
done

# Clear redirects and zones (safely)
echo "Cleaning up firewall redirects and zones..."
while uci delete firewall.@redirect[0] 2>/dev/null; do
  echo "Deleted firewall.@redirect[0]."
done
while uci delete firewall.@zone[0] 2>/dev/null; do
  echo "Deleted firewall.@zone[0]."
done
while uci delete firewall.@forwarding[0] 2>/dev/null; do
  echo "Deleted firewall.@forwarding[0]."
done

# Commit changes to apply them
echo "Committing firewall changes..."
uci commit firewall
echo "Firewall configuration completed successfully."

### --- Firewall Defaults (Drop All) ---
uci set firewall.@defaults[0].input='DROP'
uci set firewall.@defaults[0].output='DROP'
uci set firewall.@defaults[0].forward='DROP'
uci set firewall.@defaults[0].syn_flood='1'
uci set firewall.@defaults[0].drop_invalid='1'
uci set firewall.@defaults[0].flow_offloading='1'
uci set firewall.@defaults[0].flow_offloading_hw='1'

# Log the addition of zones and forwardings
echo "Adding firewall zones and forwardings..."

# Core Zone (Uses Core Zone Policy: $CORE_POLICY_IN/$CORE_POLICY_OUT/$CORE_POLICY_FORWARD)
echo "Adding Core Zone (Input: $CORE_POLICY_IN, Output: $CORE_POLICY_OUT, Forward: $CORE_POLICY_FORWARD)..."
uci set firewall.core=zone
uci set firewall.core.name='core'
uci set firewall.core.network='core'
uci set firewall.core.input="${CORE_POLICY_IN:-ACCEPT}"
uci set firewall.core.output="${CORE_POLICY_OUT:-ACCEPT}"
uci set firewall.core.forward="${CORE_POLICY_FORWARD:-REJECT}"

# Nexus Zone (Uses Other Zones Policy: $OTHER_ZONES_POLICY_IN/$OTHER_ZONES_POLICY_OUT/$OTHER_ZONES_POLICY_FORWARD)
echo "Adding Nexus Zone (Input: $OTHER_ZONES_POLICY_IN, Output: $OTHER_ZONES_POLICY_OUT, Forward: $OTHER_ZONES_POLICY_FORWARD)..."
uci set firewall.nexus=zone
uci set firewall.nexus.name='nexus'
uci set firewall.nexus.network='nexus'
uci set firewall.nexus.input="${OTHER_ZONES_POLICY_IN:-DROP}"
uci set firewall.nexus.output="${OTHER_ZONES_POLICY_OUT:-DROP}"
uci set firewall.nexus.forward="${OTHER_ZONES_POLICY_FORWARD:-DROP}"

# Nodes Zone (Uses Other Zones Policy: $OTHER_ZONES_POLICY_IN/$OTHER_ZONES_POLICY_OUT/$OTHER_ZONES_POLICY_FORWARD)
echo "Adding Nodes Zone (Input: $OTHER_ZONES_POLICY_IN, Output: $OTHER_ZONES_POLICY_OUT, Forward: $OTHER_ZONES_POLICY_FORWARD)..."
uci set firewall.nodes=zone
uci set firewall.nodes.name='nodes'
uci set firewall.nodes.network='nodes'
uci set firewall.nodes.input="${OTHER_ZONES_POLICY_IN:-DROP}"
uci set firewall.nodes.output="${OTHER_ZONES_POLICY_OUT:-DROP}"
uci set firewall.nodes.forward="${OTHER_ZONES_POLICY_FORWARD:-DROP}"

# WireGuard Zone (Uses Other Zones Policy: $OTHER_ZONES_POLICY_IN/$OTHER_ZONES_POLICY_OUT/$OTHER_ZONES_POLICY_FORWARD)
echo "Adding WireGuard Zone (Input: $OTHER_ZONES_POLICY_IN, Output: $OTHER_ZONES_POLICY_OUT, Forward: $OTHER_ZONES_POLICY_FORWARD)..."
uci set firewall.wireguard=zone
uci set firewall.wireguard.name='wireguard'
uci set firewall.wireguard.network='wireguard'
uci set firewall.wireguard.input="${OTHER_ZONES_POLICY_IN:-DROP}"
uci set firewall.wireguard.output="${OTHER_ZONES_POLICY_OUT:-DROP}"
uci set firewall.wireguard.forward="${OTHER_ZONES_POLICY_FORWARD:-DROP}"

# WAN Zone (Uses WAN Zone Policy: $WAN_POLICY_IN/$WAN_POLICY_OUT/$WAN_POLICY_FORWARD)
echo "Adding WAN Zone (Input: $WAN_POLICY_IN, Output: $WAN_POLICY_OUT, Forward: $WAN_POLICY_FORWARD)..."
uci set firewall.wan=zone
uci set firewall.wan.name='wan'
uci set firewall.wan.network='wan wan6'
uci set firewall.wan.input="${WAN_POLICY_IN:-DROP}"
uci set firewall.wan.output="${WAN_POLICY_OUT:-ACCEPT}"
uci set firewall.wan.forward="${WAN_POLICY_FORWARD:-DROP}"
uci set firewall.wan.masq='1'  # Keep NAT enabled

# Forwarding (Core -> WAN)
echo "Adding forwarding from Core to WAN..."
uci add firewall forwarding
uci set firewall.@forwarding[-1].src='core'
uci set firewall.@forwarding[-1].dest='wan'

# Port Forward: WAN -> WireGuard (Customizable IP)
# The WireGuard IP is customizable in the install.sh script by modifying the WIREGUARD_IP variable.
echo "Adding port forward from WAN to WireGuard ($WIREGUARD_IP)..."
uci add firewall redirect
uci set firewall.@redirect[-1].name='PortForwardWANtoWG'
uci set firewall.@redirect[-1].src='wan'
uci set firewall.@redirect[-1].src_dport='52018'
uci set firewall.@redirect[-1].dest='wireguard'
uci set firewall.@redirect[-1].dest_ip="$WIREGUARD_IP"
uci set firewall.@redirect[-1].proto='udp'
uci set firewall.@redirect[-1].enabled='0'

echo "Firewall zones and forwardings added successfully."

# Commit changes to apply new defaults and rules
echo "Finalizing firewall configuration..."
uci commit firewall
echo "All firewall changes have been committed successfully."