#!/usr/bin/fish
# FastWrt DHCP configuration - Implementation using fish shell
# Fish shell is the default shell in FastWrt and should be used for all scripts

# Source common color definitions
source "$PROFILE_DIR/colors.fish"

# Ensure the script runs from its own directory
cd $BASE_DIR
echo "$blue""Current working directory: ""$reset"(pwd)

# Delete any existing DHCP entries
echo "$blue""Cleaning up existing DHCP entries...""$reset"
for entry in (uci show dhcp | cut -d. -f2 | cut -d= -f1 | sort -u)
    # Skip deletion of common default entries to avoid negative entries
    if test "$entry" = "lan"; or test "$entry" = "wan"; or test "$entry" = "odhcpd"; or string match -q "cfg*" "$entry"
        echo "$yellow""Renaming rather than deleting default DHCP entry: $entry...""$reset"
        
        # Rename the section to keep its properties but avoid naming conflicts
        set timestamp (date +%s)
        uci rename dhcp.$entry=old_$entry
        echo "$green""Renamed $entry to old_$entry""$reset"
    else
        echo "$yellow""Deleting DHCP entry: $entry...""$reset"
        uci delete dhcp.$entry 2>/dev/null; or echo "$yellow""Notice: DHCP entry $entry not found, skipping deletion.""$reset"
    end
end

### --- DHCP & DNS ---
# odhcpd (persistent leases)
echo "$blue""Setting odhcpd configuration...""$reset"
uci set dhcp.odhcpd='odhcpd'
uci set dhcp.odhcpd.maindhcp='0'
uci set dhcp.odhcpd.leasefile='/var/lib/odhcpd/leases'  # Fixed path
uci set dhcp.odhcpd.leasetrigger='/usr/sbin/odhcpd-update'
uci set dhcp.odhcpd.loglevel='4'

# Configure dnsmasq settings
echo "$blue""Configuring dnsmasq settings...""$reset"
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

# FIX DNS ISSUES:
# Allow using system resolver while still using configured servers
uci set dhcp.@dnsmasq[-1].noresolv='0'  # Changed from 1 to 0 - critical fix!
uci set dhcp.@dnsmasq[-1].localservice='0'  # Allow from all networks
uci add_list dhcp.@dnsmasq[-1].server='1.1.1.1'  # Cloudflare DNS
uci add_list dhcp.@dnsmasq[-1].server='9.9.9.9'  # Quad9 DNS
uci add_list dhcp.@dnsmasq[-1].server='8.8.8.8'  # Google DNS

# Configure DHCP for all interfaces
echo "$purple""Configuring DHCP pools for all interfaces...""$reset"
# List of interfaces and their subnets - ORDER MATTERS for GUI display order
set INTERFACES core nexus nodes meta iot guest wireguard wan

# Process all non-WAN interfaces first in the specified order
for interface in $INTERFACES
  # Skip WAN in the first pass - we'll add it last
  if test "$interface" = "wan"
    continue
  end
  
  echo "$blue""Configuring DHCP for $interface interface...""$reset"
  uci set dhcp.$interface='dhcp'
  uci set dhcp.$interface.interface="$interface"
  uci set dhcp.$interface.start='200'
  uci set dhcp.$interface.limit='54'  # Adjust to stay within valid range (200-254)
  uci set dhcp.$interface.leasetime='12h'

  # Special case for wireguard
  if test "$interface" = "wireguard"
    echo "$yellow""Special configuration for WireGuard interface""$reset"
    uci set dhcp.$interface.ignore='1'  # Typically WireGuard doesn't need DHCP
  end

  # For guest network, configure different DNS to prevent internal network access
  if test "$interface" = "guest"
    echo "$yellow""Setting public DNS for guest network""$reset"
    uci add_list dhcp.$interface.dhcp_option='6,8.8.8.8,8.8.4.4'  # Use Google DNS for guests
  end
  
  # Ensure ignore is explicitly set to '0' for wireless interfaces
  if test "$interface" = "core" -o "$interface" = "guest" -o "$interface" = "iot" -o "$interface" = "meta"
    echo "$green""Ensuring DHCP is explicitly enabled for $interface""$reset"
    uci set dhcp.$interface.ignore='0'
  end
end

# Now add WAN last to ensure it appears at the end of the list in GUI
echo "$blue""Configuring WAN DHCP settings (added last for GUI order)...""$reset"
uci set dhcp.wan='dhcp'
uci set dhcp.wan.interface='wan'
uci set dhcp.wan.ignore='1'

echo "$green""DHCP pool configuration completed successfully.""$reset"

# Verify dnsmasq is running and restart if needed
echo "$blue""Verifying dnsmasq service...""$reset"
if not pidof dnsmasq > /dev/null
    echo "$yellow""dnsmasq not running, attempting to restart...""$reset"
    /etc/init.d/dnsmasq restart
    sleep 2
    if not pidof dnsmasq > /dev/null
        echo "$red""WARNING: dnsmasq failed to start. DHCP will not work.""$reset"
    else
        echo "$green""dnsmasq started successfully""$reset"
    end
else
    echo "$green""dnsmasq is running properly""$reset"
end

# Process maclist.csv for static DHCP leases
set MACLIST_FILES "$PROFILE_DIR/maclist.csv" "$CONFIG_DIR/maclist.csv" "$BASE_DIR/maclist.csv"
set MACLIST_PATH ""

for file_path in $MACLIST_FILES
  if test -f "$file_path"
    set MACLIST_PATH "$file_path"
    echo "$green""Found MAC list file at: $file_path""$reset"
    break
  end
end

if test -f "$MACLIST_PATH"
  echo "$blue""Processing maclist.csv for static DHCP leases...""$reset"
  set line_count 0
  set error_count 0
  set success_count 0
  
  # Initialize a global MAC_ADDRESSES array that will be used by the wireless script
  # This creates a robust data flow between the DHCP and wireless scripts
  set -g MAC_ADDRESSES
  
  # Using fish's builtin line reading capabilities
  while read -l line
    # Count lines for better debugging
    set line_count (math $line_count + 1)
    
    # Skip comment lines and empty lines with better detection
    if string match -q "#*" $line; or test -z (string trim "$line")
      continue
    end
    
    # Parse CSV line (mac,ip,name,network)
    begin
      set fields (string split "," $line)
      
      # Validate that we have all required fields
      if test (count $fields) -lt 4
        set error_count (math $error_count + 1)
        echo "$red""Error: Invalid line format in maclist.csv on line $line_count: $line""$reset"
        echo "$yellow""Expected format: MAC,IP,NAME,NETWORK""$reset"
        continue
      end
      
      # Extract fields and trim whitespace
      set mac_addr (string trim "$fields[1]")
      set ip_addr (string trim "$fields[2]")
      set device_name (string trim "$fields[3]")
      set network_name (string trim "$fields[4]")
      
      # Validate MAC address format with more flexible regex
      if not string match -q -r '^([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})$' "$mac_addr"
        set error_count (math $error_count + 1)
        echo "$red""Error: Invalid MAC address format in maclist.csv line $line_count: '$mac_addr'""$reset"
        continue
      end
      
      # Convert device name to a safe UCI section name (replace hyphens and spaces with underscores)
      set device_section (string replace -a "-" "_" "$device_name" | string replace -a " " "_")
      
      echo "$blue""Setting up static lease for $device_name ($mac_addr -> $ip_addr)""$reset"
      
      # Add static lease with proper UCI syntax - ensuring proper quoting and handling
      uci set "dhcp.$device_section=host"
      uci set "dhcp.$device_section.name=$device_name"
      uci set "dhcp.$device_section.mac=$mac_addr"
      uci set "dhcp.$device_section.ip=$ip_addr"
      
      # Only set network if it's not empty
      if test -n "$network_name" 
        uci set "dhcp.$device_section.interface=$network_name"
        echo "$green""Added static DHCP lease for $device_name on network $network_name""$reset"
      else
        echo "$yellow""Warning: No network specified for $device_name, using default""$reset"
        uci set "dhcp.$device_section.interface=core"
      end
      
      # Store MAC addresses with proper metadata for wireless filtering
      # Format: MAC:DEVICE_NAME:NETWORK_NAME
      # This ensures the wireless script has all information needed for proper filtering
      set -a MAC_ADDRESSES "$mac_addr:$device_name:$network_name"
      
      set success_count (math $success_count + 1)
    end
  end < "$MACLIST_PATH"
  
  # Summary output
  echo "$green""Configured $success_count static DHCP leases from maclist.csv""$reset"
  # Clearly communicate that MAC addresses are ready for wireless configuration
  echo "$green""Prepared $success_count MAC addresses for wireless filtering""$reset"
  if test $error_count -gt 0
    echo "$yellow""Encountered $error_count errors while processing MAC list""$reset"
  end
else
  echo "$yellow""Maclist file not found at: $MACLIST_PATH, skipping static lease configuration.""$reset"
  # Set empty MAC_ADDRESSES array to prevent errors in wireless script
  set -g MAC_ADDRESSES
end

# Note: UCI commits are handled in 98-commit.sh
echo "$green""DHCP and DNS configuration completed successfully. Changes will be applied during final commit.""$reset"
