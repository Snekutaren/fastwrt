#!/usr/bin/fish
# FastWrt firewall configuration script - Pure fish implementation

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

#############################################
# SECTION 1: CLEANUP & INITIAL CONFIGURATION
#############################################

# Log all existing rules before cleanup for debugging
echo "$blue""Existing rules before cleanup:""$reset"
uci show firewall | grep '@rule' | sort

# Find and preserve any default rules we want to keep (by rule name)
echo "$blue""Preserving default system rules...""$reset"
set preserved_rules
set rule_configs

# Use associative arrays to ensure uniqueness of preserved rules
set -g preserved_rule_names
set -g preserved_rule_sections

# Check for existing named rules to preserve
for rule in (uci show firewall | grep '@rule' | cut -d. -f2 | cut -d= -f1 | sort -u)
  set rule_name (uci -q get firewall.$rule.name)
  
  # Only preserve essential system rules, not our custom ones
  if string match -q "Allow-DHCP-Renew" "$rule_name"; or \
     string match -q "Allow-Ping" "$rule_name"; or \
     string match -q "Allow-DHCPv6" "$rule_name"; or \
     string match -q "Allow-ICMPv6-Input" "$rule_name"; or \
     string match -q "Allow-ICMPv6-Forward" "$rule_name"
     
    # Skip if we already processed this rule name
    if contains "$rule_name" $preserved_rule_names
      continue
    end
    
    echo "$green""Preserving essential system rule: $rule_name""$reset"
    
    # Store the rule name and section to be restored later
    set -a preserved_rule_names "$rule_name"
    set -a preserved_rule_sections "$rule"
    
    # Store rule configuration in array
    # Format: "rule_name|property=value|property2=value2|..."
    set rule_config (uci show firewall.$rule | tr '\n' '|')
    set -a rule_configs "$rule_name|$rule_config"
  else
    echo "$yellow""Will remove rule: $rule ($rule_name)""$reset"
  end
end

# Clear all firewall configuration completely
echo "$blue""Cleaning up firewall configuration...""$reset"

# Clear redirects
while uci -q delete firewall.@redirect[0] > /dev/null
  echo "$green""Deleted firewall.@redirect[0]""$reset"
end

# Clear rules
while uci -q delete firewall.@rule[0] > /dev/null
  echo "$green""Deleted firewall.@rule[0]""$reset"
end

# Clear forwarding
while uci -q delete firewall.@forwarding[0] > /dev/null
  echo "$green""Deleted firewall.@forwarding[0]""$reset"
end

# Clear zones (except defaults)
while uci -q delete firewall.@zone[0] > /dev/null
  echo "$green""Deleted firewall.@zone[0]""$reset"
end

# Firewall Defaults (Drop All)
echo "$blue""Setting global firewall defaults...""$reset"
uci set firewall.@defaults[0].input='DROP'
uci set firewall.@defaults[0].output='DROP'
uci set firewall.@defaults[0].forward='DROP'
uci set firewall.@defaults[0].syn_flood='1'
uci set firewall.@defaults[0].drop_invalid='1'
uci set firewall.@defaults[0].flow_offloading='1'
uci set firewall.@defaults[0].flow_offloading_hw='1'

# Re-add the essential system rules we preserved with proper names
echo "$blue""Restoring preserved system rules...""$reset"
set restored_rules

# Track rules we've already restored to avoid duplicates
for i in (seq (count $preserved_rule_names))
  set rule_name $preserved_rule_names[$i]
  
  # Skip if we already restored this rule
  if contains "$rule_name" $restored_rules
    continue
  end
  
  echo "$green""Re-adding system rule: $rule_name""$reset"
  set -a restored_rules "$rule_name"
  
  # Create new rule with proper name as section identifier (sanitized for UCI)
  set rule_section (string replace -a "-" "_" $rule_name | string lower)
  uci set firewall.$rule_section='rule'
  uci set firewall.$rule_section.name="$rule_name"
  
  # Find the stored rule properties for this rule name
  for config_entry in $rule_configs
    set parts (string split "|" $config_entry)
    set stored_rule_name $parts[1]
    
    # Skip if this isn't the rule we're looking for
    if test "$stored_rule_name" != "$rule_name"
      continue
    end
    
    # Process the rule configuration (skip first part, which is rule name)
    for i in (seq 2 (count $parts))
      set prop $parts[$i]
      if test -n "$prop"
        # Extract property name and value
        set prop_parts (string match -r '([^=]+)=(.*)' "$prop")
        if test (count $prop_parts) -ge 3
          set prop_name $prop_parts[2]
          set prop_value $prop_parts[3]
          
          # Skip if prop_name contains '.' or is 'name' (we already set it)
          if not string match -q "*.*" "$prop_name"; and test "$prop_name" != "name"
            # Remove quotes from the value
            set prop_value (string trim -c "'" "$prop_value")
            
            # Set the property
            uci set firewall.$rule_section.$prop_name="$prop_value"
            echo "$yellow""  Setting $prop_name=$prop_value""$reset"
          end
        end
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

echo "$blue""Adding firewall zones...""$reset"

# Core Zone
echo "$green""Adding Core Zone (Input: $CORE_POLICY_IN, Output: $CORE_POLICY_OUT, Forward: $CORE_POLICY_FORWARD)...""$reset"
uci set firewall.core='zone'
uci set firewall.core.name='core'
uci set firewall.core.network='core'
uci set firewall.core.input="$CORE_POLICY_IN"
uci set firewall.core.output="$CORE_POLICY_OUT"
uci set firewall.core.forward="$CORE_POLICY_FORWARD"

# Nexus Zone
echo "$green""Adding Nexus Zone...""$reset"
uci set firewall.nexus='zone'
uci set firewall.nexus.name='nexus'
uci set firewall.nexus.network='nexus'
uci set firewall.nexus.input="$OTHER_ZONES_POLICY_IN"
uci set firewall.nexus.output="$OTHER_ZONES_POLICY_OUT"
uci set firewall.nexus.forward="$OTHER_ZONES_POLICY_FORWARD"

# Nodes Zone
echo "$green""Adding Nodes Zone...""$reset"
uci set firewall.nodes='zone'
uci set firewall.nodes.name='nodes'
uci set firewall.nodes.network='nodes'
uci set firewall.nodes.input="$OTHER_ZONES_POLICY_IN"
uci set firewall.nodes.output="$OTHER_ZONES_POLICY_OUT"
uci set firewall.nodes.forward="$OTHER_ZONES_POLICY_FORWARD"

# Meta Zone
echo "$green""Adding Meta Zone...""$reset"
uci set firewall.meta='zone'
uci set firewall.meta.name='meta'
uci set firewall.meta.network='meta'
uci set firewall.meta.input="$OTHER_ZONES_POLICY_IN"
uci set firewall.meta.output="$OTHER_ZONES_POLICY_OUT"
uci set firewall.meta.forward="$OTHER_ZONES_POLICY_FORWARD"

# IoT Zone
echo "$green""Adding IoT Zone...""$reset"
uci set firewall.iot='zone'
uci set firewall.iot.name='iot'
uci set firewall.iot.network='iot'
uci set firewall.iot.input="$OTHER_ZONES_POLICY_IN"
uci set firewall.iot.output="$OTHER_ZONES_POLICY_OUT"
uci set firewall.iot.forward="$OTHER_ZONES_POLICY_FORWARD"

# Guest Zone
echo "$green""Adding Guest Zone...""$reset"
uci set firewall.guest='zone'
uci set firewall.guest.name='guest'
uci set firewall.guest.network='guest'
uci set firewall.guest.input="$OTHER_ZONES_POLICY_IN"
uci set firewall.guest.output="$OTHER_ZONES_POLICY_OUT"
uci set firewall.guest.forward="$OTHER_ZONES_POLICY_FORWARD"

# WireGuard Zone
echo "$green""Adding WireGuard Zone...""$reset"
uci set firewall.wireguard='zone'
uci set firewall.wireguard.name='wireguard'
uci set firewall.wireguard.network='wireguard'
uci set firewall.wireguard.input="$OTHER_ZONES_POLICY_IN"
uci set firewall.wireguard.output="$OTHER_ZONES_POLICY_OUT"
uci set firewall.wireguard.forward="$OTHER_ZONES_POLICY_FORWARD"

# WAN Zone
echo "$green""Adding WAN Zone...""$reset"
uci set firewall.wan_zone='zone'
uci set firewall.wan_zone.name='wan'
uci set firewall.wan_zone.network='wan wan6'
uci set firewall.wan_zone.input="$WAN_POLICY_IN"
uci set firewall.wan_zone.output="$WAN_POLICY_OUT"
uci set firewall.wan_zone.forward="$WAN_POLICY_FORWARD"
uci set firewall.wan_zone.masq='1'  # Keep NAT enabled

##################################
# SECTION 2.1: SSH ACCESS RULES
##################################

echo "$blue""Configuring SSH firewall access rules...""$reset"

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

# SSH rate limiting rule
uci set firewall.ssh_limit='rule'
uci set firewall.ssh_limit.name='SSH-Limit'
uci set firewall.ssh_limit.src='wan'
uci set firewall.ssh_limit.proto='tcp'
uci set firewall.ssh_limit.dest_port='6622'
uci set firewall.ssh_limit.limit='10/minute'
uci set firewall.ssh_limit.target='ACCEPT'
uci set firewall.ssh_limit.enabled='0'  # Disabled by default, enable in secure_ssh.sh

# Enhanced SSH protection with connection tracking
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

echo "$blue""Configuring special disabled rules (VPN and multicast)...""$reset"

# Add disabled IPSec-ESP and ISAKMP rules for core
echo "$green""Adding disabled IPSec/VPN rules...""$reset"
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

# Check if MULTICAST_RULES is defined before using it
set -q MULTICAST_RULES; or set MULTICAST_RULES

# Add default multicast rules
echo "$blue""Creating default multicast rules (disabled)...""$reset"

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

####################################
# SECTION 3: ZONE FORWARDING RULES
####################################

echo "$blue""Configuring zone forwarding rules...""$reset"

# First verify that all required networks exist
set required_networks core guest iot meta nexus nodes wireguard wan
set missing_networks

for net in $required_networks
    if not uci -q get "network.$net" > /dev/null
        set -a missing_networks $net
    end
end

if test (count $missing_networks) -gt 0
    echo "$red""ERROR: The following networks referenced in firewall aren't defined: ""$reset"(string join ", " $missing_networks)
    echo "$red""Network interfaces must be properly configured in 30-network.sh before firewall configuration.""$reset"
    echo "$red""Aborting firewall configuration to prevent security issues.""$reset"
    exit 1
end  # Added missing 'end' statement here

# Continue with forwarding rules
# Core to WAN (Internet access for ClosedWrt network)
echo "$green""Adding forwarding from Core to WAN...""$reset"
uci set firewall.forward_core_to_wan='forwarding'
uci set firewall.forward_core_to_wan.src='core'
uci set firewall.forward_core_to_wan.dest='wan'

# Guest to WAN (Internet access for OpenWrt network)
echo "$green""Adding forwarding from Guest to WAN for internet access...""$reset"
uci set firewall.forward_guest_to_wan='forwarding'
uci set firewall.forward_guest_to_wan.src='guest'
uci set firewall.forward_guest_to_wan.dest='wan'

# Allow all zones to get DHCP, even without internet access
echo "$blue""Adding DHCP access rules for all other zones (without internet access)...""$reset"

# For IoT network
echo "$green""Adding DHCP access for IoT network...""$reset"
uci set firewall.allow_dhcp_iot='rule'
uci set firewall.allow_dhcp_iot.name='Allow-DHCP-IoT'
uci set firewall.allow_dhcp_iot.src='iot'
uci set firewall.allow_dhcp_iot.proto='udp'
uci set firewall.allow_dhcp_iot.dest_port='67 68'
uci set firewall.allow_dhcp_iot.target='ACCEPT'

# For Meta network
echo "$green""Adding DHCP access for Meta network...""$reset"
uci set firewall.allow_dhcp_meta='rule'
uci set firewall.allow_dhcp_meta.name='Allow-DHCP-Meta'
uci set firewall.allow_dhcp_meta.src='meta'
uci set firewall.allow_dhcp_meta.proto='udp'
uci set firewall.allow_dhcp_meta.dest_port='67 68'
uci set firewall.allow_dhcp_meta.target='ACCEPT'

# For Nexus network
echo "$green""Adding DHCP access for Nexus network...""$reset"
uci set firewall.allow_dhcp_nexus='rule'
uci set firewall.allow_dhcp_nexus.name='Allow-DHCP-Nexus'
uci set firewall.allow_dhcp_nexus.src='nexus'
uci set firewall.allow_dhcp_nexus.proto='udp'
uci set firewall.allow_dhcp_nexus.dest_port='67 68'
uci set firewall.allow_dhcp_nexus.target='ACCEPT'

# For Nodes network
echo "$green""Adding DHCP access for Nodes network...""$reset"
uci set firewall.allow_dhcp_nodes='rule'
uci set firewall.allow_dhcp_nodes.name='Allow-DHCP-Nodes'
uci set firewall.allow_dhcp_nodes.src='nodes'
uci set firewall.allow_dhcp_nodes.proto='udp'
uci set firewall.allow_dhcp_nodes.dest_port='67 68'
uci set firewall.allow_dhcp_nodes.target='ACCEPT'

######################################
# SECTION 4: DNS CONFIGURATION RULES
######################################

echo "$blue""Configuring DNS rules and enforcement...""$reset"

# Allow DNS for guest network specifically
echo "$green""Adding DNS access for guest network...""$reset"
uci set firewall.allow_dns_guest='rule'
uci set firewall.allow_dns_guest.name='Allow-DNS-Guest'
uci set firewall.allow_dns_guest.src='guest'
uci set firewall.allow_dns_guest.proto='tcp udp'
uci set firewall.allow_dns_guest.dest_port='53'
uci set firewall.allow_dns_guest.target='ACCEPT'
uci set firewall.allow_dns_guest.enabled='1'

# DNS enforcement - force all clients to use router DNS
echo "$blue""Adding DNS enforcement rules to redirect all DNS queries to router...""$reset"

# Add per-zone rules for DNS redirection
for zone in core nexus nodes meta iot guest
  echo "$green""Creating NAT rules to redirect DNS traffic to router for zone $zone...""$reset"
  
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
echo "$blue""Blocking direct external DNS access except from router...""$reset"
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

echo "$blue""Configuring service and protocol specific rules...""$reset"

# Guest DHCP rule - Allow guest network to get DHCP addresses
echo "$green""Adding rule to allow guest network to acquire DHCP addresses...""$reset"
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

echo "$blue""Configuring port forwarding rules...""$reset"

# Port Forward: WAN -> WireGuard
echo "$green""Adding port forward from WAN to WireGuard ($WIREGUARD_IP)...""$reset"
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
# Note: UCI commits are handled by the parent script
echo "$green""Firewall configuration completed successfully. Changes will be applied during final commit.""$reset"