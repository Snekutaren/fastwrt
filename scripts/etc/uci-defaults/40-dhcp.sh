#!/usr/bin/fish
# FastWrt DHCP configuration - Implementation using fish shell

# Source common color definitions
source "$PROFILE_DIR/colors.fish"

# Ensure the script runs from its own directory
cd $BASE_DIR
echo "$blue""Current working directory: ""$reset"(pwd)

# Clean up ALL DHCP entries for full idempotency
echo "$blue""Resetting all DHCP configurations...""$reset"
for entry in (uci show dhcp | cut -d. -f2 | cut -d= -f1 | sort -u)
    echo "$yellow""Deleting DHCP entry: $entry""$reset"
    uci delete dhcp.$entry 2>/dev/null; or echo "$yellow""Notice: DHCP entry $entry not found, skipping.""$reset"
end

# Ensure no dnsmasq sections remain
echo "$blue""Ensuring no residual dnsmasq sections...""$reset"
uci delete dhcp.dnsmasq 2>/dev/null; or echo "$yellow""Notice: No dnsmasq section found, skipping.""$reset"

### --- DHCP & DNS ---
# odhcpd (persistent leases)
echo "$blue""Setting odhcpd configuration...""$reset"
uci set dhcp.odhcpd='odhcpd'
uci set dhcp.odhcpd.maindhcp='0'
uci set dhcp.odhcpd.leasefile='/var/lib/odhcpd/leases'
uci set dhcp.odhcpd.leasetrigger='/usr/sbin/odhcpd-update'
uci set dhcp.odhcpd.loglevel='4'

# Configure dnsmasq settings
echo "$blue""Configuring dnsmasq settings...""$reset"
uci set dhcp.dnsmasq='dnsmasq'; or echo "$red""Failed to set dhcp.dnsmasq='dnsmasq'""$reset"
uci set dhcp.dnsmasq.domainneeded='1'; or echo "$red""Failed to set dhcp.dnsmasq.domainneeded='1'""$reset"
uci set dhcp.dnsmasq.boguspriv='1'; or echo "$red""Failed to set dhcp.dnsmasq.boguspriv='1'""$reset"
uci set dhcp.dnsmasq.filterwin2k='0'; or echo "$red""Failed to set dhcp.dnsmasq.filterwin2k='0'""$reset"
uci set dhcp.dnsmasq.localise_queries='1'; or echo "$red""Failed to set dhcp.dnsmasq.localise_queries='1'""$reset"
uci set dhcp.dnsmasq.rebind_protection='1'; or echo "$red""Failed to set dhcp.dnsmasq.rebind_protection='1'""$reset"
uci set dhcp.dnsmasq.rebind_localhost='1'; or echo "$red""Failed to set dhcp.dnsmasq.rebind_localhost='1'""$reset"
uci set dhcp.dnsmasq.local='/lan/'; or echo "$red""Failed to set dhcp.dnsmasq.local='/lan/'""$reset"
uci set dhcp.dnsmasq.domain='lan'; or echo "$red""Failed to set dhcp.dnsmasq.domain='lan'""$reset"
uci set dhcp.dnsmasq.expandhosts='1'; or echo "$red""Failed to set dhcp.dnsmasq.expandhosts='1'""$reset"
uci set dhcp.dnsmasq.nonegcache='0'; or echo "$red""Failed to set dhcp.dnsmasq.nonegcache='0'""$reset"
uci set dhcp.dnsmasq.cachesize='1000'; or echo "$red""Failed to set dhcp.dnsmasq.cachesize='1000'""$reset"
uci set dhcp.dnsmasq.authoritative='1'; or echo "$red""Failed to set dhcp.dnsmasq.authoritative='1'""$reset"
uci set dhcp.dnsmasq.readethers='1'; or echo "$red""Failed to set dhcp.dnsmasq.readethers='1'""$reset"
uci set dhcp.dnsmasq.leasefile='/tmp/dhcp.leases'; or echo "$red""Failed to set dhcp.dnsmasq.leasefile='/tmp/dhcp.leases'""$reset"
uci set dhcp.dnsmasq.resolvfile='/tmp/resolv.conf.d/resolv.conf.auto'; or echo "$red""Failed to set dhcp.dnsmasq.resolvfile='/tmp/resolv.conf.d/resolv.conf.auto'""$reset"
uci set dhcp.dnsmasq.localservice='1'; or echo "$red""Failed to set dhcp.dnsmasq.localservice='1'""$reset"
uci add_list dhcp.dnsmasq.interface='core'; or echo "$red""Failed to add_list dhcp.dnsmasq.interface='core'""$reset"
uci add_list dhcp.dnsmasq.interface='guest'; or echo "$red""Failed to add_list dhcp.dnsmasq.interface='guest'""$reset"
uci add_list dhcp.dnsmasq.interface='iot'; or echo "$red""Failed to add_list dhcp.dnsmasq.interface='iot'""$reset"
uci add_list dhcp.dnsmasq.interface='meta'; or echo "$red""Failed to add_list dhcp.dnsmasq.interface='meta'""$reset"
uci add_list dhcp.dnsmasq.interface='nexus'; or echo "$red""Failed to add_list dhcp.dnsmasq.interface='nexus'""$reset"
uci add_list dhcp.dnsmasq.interface='nodes'; or echo "$red""Failed to add_list dhcp.dnsmasq.interface='nodes'""$reset"
uci add_list dhcp.dnsmasq.interface='wireguard'; or echo "$red""Failed to add_list dhcp.dnsmasq.interface='wireguard'""$reset"
uci add_list dhcp.dnsmasq.notinterface='wan'; or echo "$red""Failed to add_list dhcp.dnsmasq.notinterface='wan'""$reset"
uci set dhcp.dnsmasq.noresolv='0'; or echo "$red""Failed to set dhcp.dnsmasq.noresolv='0'""$reset"
uci set dhcp.dnsmasq.listen_ipv6='0'; or echo "$red""Failed to set dhcp.dnsmasq.listen_ipv6='0'""$reset"
uci add_list dhcp.dnsmasq.server='1.1.1.1'; or echo "$red""Failed to add_list dhcp.dnsmasq.server='1.1.1.1'""$reset"
uci add_list dhcp.dnsmasq.server='9.9.9.9'; or echo "$red""Failed to add_list dhcp.dnsmasq.server='9.9.9.9'""$reset"
uci add_list dhcp.dnsmasq.server='8.8.8.8'; or echo "$red""Failed to add_list dhcp.dnsmasq.server='8.8.8.8'""$reset"
uci add_list dhcp.dnsmasq.server='192.168.10.1'; or echo "$red""Failed to add_list dhcp.dnsmasq.server='192.168.10.1'""$reset"

# Disable IPv6
uci set network.wan6.disabled='1'; or echo "$red""Failed to set network.wan6.disabled='1'""$reset"
uci delete network.wan6 2>/dev/null; or echo "$yellow""Notice: network.wan6 not found, skipping.""$reset"
uci set dhcp.lan.dhcpv6='disabled'; or echo "$red""Failed to set dhcp.lan.dhcpv6='disabled'""$reset"
uci set dhcp.lan.ra='disabled'; or echo "$red""Failed to set dhcp.lan.ra='disabled'""$reset"

# Configure DHCP for all interfaces
echo "$purple""Configuring DHCP pools for all interfaces...""$reset"
set VALID_INTERFACES core guest iot meta nexus nodes wireguard
for interface in $VALID_INTERFACES
    echo "$blue""Configuring DHCP for $interface interface...""$reset"
    uci set dhcp.$interface='dhcp'; or echo "$red""Failed to set dhcp.$interface='dhcp'""$reset"
    uci set dhcp.$interface.interface="$interface"; or echo "$red""Failed to set dhcp.$interface.interface='$interface'""$reset"
    uci set dhcp.$interface.start='200'; or echo "$red""Failed to set dhcp.$interface.start='200'""$reset"
    uci set dhcp.$interface.limit='54'; or echo "$red""Failed to set dhcp.$interface.limit='54'""$reset"
    uci set dhcp.$interface.leasetime='12h'; or echo "$red""Failed to set dhcp.$interface.leasetime='12h'""$reset"

    # Special case for wireguard
    if test "$interface" = "wireguard"
        echo "$yellow""Special configuration for WireGuard interface""$reset"
        uci set dhcp.$interface.ignore='1'; or echo "$red""Failed to set dhcp.$interface.ignore='1'""$reset"
    end

    # Ensure ignore is explicitly set to '0' for wireless interfaces
    if test "$interface" = "core" -o "$interface" = "guest" -o "$interface" = "iot" -o "$interface" = "meta"
        echo "$green""Ensuring DHCP is explicitly enabled for $interface""$reset"
        uci set dhcp.$interface.ignore='0'; or echo "$red""Failed to set dhcp.$interface.ignore='0'""$reset"
    end
end

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
    set -g MAC_ADDRESSES

    for line in (cat "$MACLIST_PATH")
        set line_count (math $line_count + 1)
        set trimmed (string trim "$line")
        if string match -q "#*" -- $trimmed; or test -z "$trimmed"
            continue
        end

        set fields (string split "," -- $trimmed)
        if test (count $fields) -lt 4
            set error_count (math $error_count + 1)
            echo "$red""Error: Invalid line format in maclist.csv on line $line_count: $line""$reset"
            echo "$yellow""Expected format: MAC,IP,NAME,NETWORK""$reset"
            continue
        end

        set mac_addr (string trim "$fields[1]")
        set ip_addr (string trim "$fields[2]")
        set device_name (string trim "$fields[3]")
        set network_name (string trim "$fields[4]")

        if not string match -q -r '^([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})$' "$mac_addr"
            set error_count (math $error_count + 1)
            echo "$red""Error: Invalid MAC address format in maclist.csv line $line_count: '$mac_addr'""$reset"
            continue
        end

        set device_section (string replace -a "-" "_" "$device_name" | string replace -a " " "_")
        echo "$blue""Setting up static lease for $device_name ($mac_addr -> $ip_addr)""$reset"
        uci set "dhcp.$device_section=host"; or echo "$red""Failed to set dhcp.$device_section=host""$reset"
        uci set "dhcp.$device_section.name=$device_name"; or echo "$red""Failed to set dhcp.$device_section.name='$device_name'""$reset"
        uci set "dhcp.$device_section.mac=$mac_addr"; or echo "$red""Failed to set dhcp.$device_section.mac='$mac_addr'""$reset"
        uci set "dhcp.$device_section.ip=$ip_addr"; or echo "$red""Failed to set dhcp.$device_section.ip='$ip_addr'""$reset"

        if test -n "$network_name"
            uci set "dhcp.$device_section.interface=$network_name"; or echo "$red""Failed to set dhcp.$device_section.interface='$network_name'""$reset"
            echo "$green""Added static DHCP lease for $device_name on network $network_name""$reset"
        else
            echo "$yellow""Warning: No network specified for $device_name, using default""$reset"
            uci set "dhcp.$device_section.interface=core"; or echo "$red""Failed to set dhcp.$device_section.interface='core'""$reset"
        end

        set -a MAC_ADDRESSES "$mac_addr:$device_name:$network_name"
        set success_count (math $success_count + 1)
    end

    if test "$DEBUG" = "true"
        echo "$yellow""MAC_ADDRESSES loaded:""$reset"
        for mac in $MAC_ADDRESSES
            echo "$yellow""  $mac""$reset"
        end
        echo "$yellow""Total MAC_ADDRESSES: "(count $MAC_ADDRESSES)"$reset"
    end

    echo "$green""Configured $success_count static DHCP leases from maclist.csv""$reset"
    echo "$green""Prepared $success_count MAC addresses for wireless filtering""$reset"
    if test $error_count -gt 0
        echo "$yellow""Encountered $error_count errors while processing MAC list""$reset"
    end
else
    echo "$yellow""Maclist file not found at: $MACLIST_PATH, skipping static lease configuration.""$reset"
    set -g MAC_ADDRESSES
end

echo "$green""DHCP and DNS configuration completed successfully. Changes will be applied during final commit.""$reset"