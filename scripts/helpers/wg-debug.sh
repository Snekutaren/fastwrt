#!/usr/bin/fish
# WireGuard Debugging Script
# Performs comprehensive tests for troubleshooting WireGuard connectivity issues

# Set colors for better readability
set green (echo -e "\033[0;32m")
set yellow (echo -e "\033[0;33m")
set red (echo -e "\033[0;31m")
set blue (echo -e "\033[0;34m")
set purple (echo -e "\033[0;35m")
set reset (echo -e "\033[0m")

echo "$purple""FastWrt WireGuard Diagnostics""$reset"
echo ""

echo "$yellow""1. WireGuard Interface Status""$reset"
ip -br a show wireguard
echo ""

echo "$yellow""2. WireGuard Configuration""$reset"
wg show wireguard
echo ""

echo "$yellow""3. Route Information""$reset"
# Improve route checking with better error handling
ip route show | grep -E "10\.255\.0\.0/24|wireguard" || echo "$yellow""No specific routes found for WireGuard subnet""$reset"

echo "$blue""Default routes:""$reset"
ip route show default || echo "$yellow""No default routes configured""$reset"

# Add manual interface route check as fallback
echo "$blue""Interface routing table:""$reset"
ip route show table all | grep -E "wireguard|wg" || echo "$yellow""No interface-specific routes for WireGuard found""$reset"
echo ""

echo "$yellow""4. Firewall Zone Configuration""$reset"
uci show firewall | grep wireguard
echo ""

echo "$yellow""5. Checking if WireGuard is correctly forwarding to WAN""$reset"
uci show firewall | grep 'forward.*wireguard.*wan'
echo ""

# Check port forwarding with better compatibility for BusyBox
echo "$yellow""6. Testing WireGuard Port""$reset"
if command -v nc >/dev/null 2>&1
    echo "$blue""Checking if port 52018 is open (locally):""$reset"
    # Use simplified BusyBox-compatible netcat syntax
    echo "PING" | nc -w 1 localhost 52018 >/dev/null 2>&1
    if test $status -eq 0
        echo "$green""✓ Port 52018 appears to be open and accepting connections""$reset"
    else
        echo "$yellow""Port 52018 doesn't seem to respond to connection attempts""$reset"
        echo "$blue""This is expected for UDP ports when not in active communication""$reset"
    end
else
    echo "$yellow""Netcat not installed, using alternative port check...""$reset"
    # Alternative method using /proc filesystem if available
    if test -f /proc/net/udp
        set port_hex (printf "%04X" 52018)
        if grep -i ":$port_hex" /proc/net/udp >/dev/null 2>&1
            echo "$green""✓ UDP port 52018 found in /proc/net/udp - something is listening""$reset"
        else
            echo "$yellow""✗ No process appears to be listening on UDP port 52018""$reset"
            echo "$red""Check if WireGuard is properly started""$reset"
        end
    else
        echo "$yellow""Cannot check port status - netcat not available and /proc/net/udp not accessible""$reset"
        echo "$yellow""Install netcat with 'opkg update && opkg install netcat' for better diagnostics""$reset"
    end
end
echo ""

echo "$yellow""7. Checking SSH Access from WireGuard""$reset"
echo "$blue""SSH Configuration:""$reset"
uci show dropbear | grep Interface

# Check if SSH is listening on required interfaces
echo "$blue""SSH listening status:""$reset"
netstat -tulpn | grep dropbear

# Check firewall rule allowing SSH from WireGuard
echo "$blue""SSH firewall rules for WireGuard:""$reset"
uci show firewall | grep -E "wireguard.*(6622|ssh)"

# Test SSH connectivity from current device
echo "$blue""Testing SSH connectivity to router (port 6622):""$reset"
nc -zv localhost 6622 2>&1 || echo "SSH port not responding on localhost"

echo ""
echo "$yellow""8. Mobile ISP WireGuard Connection Troubleshooting""$reset"
echo "$blue""Common issues when connecting through mobile networks:""$reset"
echo "1) $yellow""Mobile carrier might use CGN (Carrier-Grade NAT)""$reset"
echo "2) $yellow""Connection tracking or keep-alive issues""$reset"
echo "3) $yellow""Source IP routing problems""$reset"

echo "$blue""Current WireGuard peer connections:""$reset"
wg show wireguard endpoints

echo "$blue""Testing SSH connection parameters:""$reset"
echo "$green""When connecting from mobile ISP, try these adjustments:""$reset"
echo "- Use explicit server IP: $yellow""ssh -v -p 6622 root@10.255.0.1""$reset"
echo "- Add connection timeout: $yellow""ssh -v -o ConnectTimeout=10 -p 6622 root@10.255.0.1""$reset"
echo "- Force IPv4: $yellow""ssh -v -4 -p 6622 root@10.255.0.1""$reset"
echo "- Add persistent keepalive to WireGuard config: $yellow""PersistentKeepalive = 25""$reset"

# Check WireGuard persistent keepalive settings
echo "$blue""Verifying WireGuard PersistentKeepalive settings:""$reset"
for peer in (wg show wireguard | grep -A 4 "peer" | grep -v "peer" | grep -E "allowed|endpoint|keepalive|transfer")
    echo "$peer"
end

echo "$blue""Checking PMTU settings (mobile ISPs often have different MTU):""$reset"
ip link show wireguard | grep mtu

# Check if connection tracking is enabled (important for mobile connections)
echo "$blue""Checking connection tracking status:""$reset"
sysctl net.netfilter.nf_conntrack_udp_timeout_stream || echo "$yellow""Connection tracking module may not be loaded""$reset"

# Check dropbear binding - ensure it's bound to ALL interfaces
echo "$blue""Checking Dropbear binding configuration:""$reset"
if test "$(uci -q get dropbear.@dropbear[0].Interface)" = "wireguard"
    echo "$yellow""Dropbear bound only to wireguard interface - try binding to all interfaces:""$reset"
    echo "$green""Run: uci set dropbear.@dropbear[0].Interface='*' && uci commit dropbear && /etc/init.d/dropbear restart""$reset"
elif test "$(uci -q get dropbear.@dropbear[0].Interface)" = "core wireguard"
    echo "$green""Dropbear correctly bound to core and wireguard interfaces""$reset"
else
    echo "$yellow""Try changing Dropbear to bind to all interfaces:""$reset"
    echo "$green""Run: uci set dropbear.@dropbear[0].Interface='*' && uci commit dropbear && /etc/init.d/dropbear restart""$reset"
end

echo ""
echo "$yellow""9. Connection troubleshooting tips:""$reset"
echo "$green""- Ensure you're connecting to SSH on port 6622, not the standard port 22""$reset"
echo "$green""- Use the WireGuard IP address of the router (10.255.0.1)""$reset"
echo "$green""- Command should be: ssh root@10.255.0.1 -p 6622""$reset"
echo "$green""- Verify WireGuard is properly connected before attempting SSH""$reset"
echo ""

echo "$yellow""9. Fix SSH Access:""$reset"
echo "$blue""Would you like to modify Dropbear to listen on multiple interfaces? (y/n)""$reset"
read -l answer
if test "$answer" = "y"
    echo "$yellow""Modifying Dropbear configuration...""$reset"
    uci set dropbear.@dropbear[0].Interface='core wireguard'
    uci commit dropbear
    /etc/init.d/dropbear restart
    echo "$green""Dropbear configured to listen on both core and wireguard interfaces""$reset"
    echo "$green""SSH should now be accessible from WireGuard clients""$reset"
else
    echo "$yellow""No changes made to Dropbear configuration""$reset"
end

echo ""
echo "$yellow""10. Add test user for SSH access? (y/n)""$reset"
read -l answer
if test "$answer" = "y"
    echo "$yellow""Creating test user with password access...""$reset"
    # Temporary allow password auth
    uci set dropbear.@dropbear[0].PasswordAuth='on'
    uci commit dropbear
    /etc/init.d/dropbear restart
    
    # Set root password for testing
    echo "$yellow""Setting temporary root password to 'fastwrt'...""$reset"
    echo -e "fastwrt\nfastwrt" | passwd root
    
    echo "$green""Test access with: ssh root@10.255.0.1 -p 6622""$reset"
    echo "$green""Password is: fastwrt""$reset"
else
    echo "$yellow""No test user created""$reset"
end

echo ""
echo "$yellow""11. Check WireGuard Masquerading Configuration:""$reset"
echo "$blue""Firewall WAN zone masquerading:""$reset"
uci -q get firewall.wan_zone.masq || echo "$red""WAN zone masquerading not configured!""$reset"

echo "$blue""WireGuard zone settings:""$reset"
uci -q show firewall.wireguard

echo "$blue""WireGuard forwarding to WAN:""$reset"
uci -q show firewall.forward_wg_to_wan || echo "$red""Missing WireGuard to WAN forwarding rule!""$reset"

echo ""
echo "$yellow""12. Check Network Configuration:""$reset"
echo "$blue""WireGuard Interface Configuration:""$reset"
uci -q show network.wireguard

echo ""
echo "$blue""Testing WireGuard interface connectivity:""$reset"
if ip link show wireguard >/dev/null 2>&1
    echo "$green""✓ WireGuard interface exists""$reset"
    if ip -br a show wireguard | grep -q "UP"
        echo "$green""✓ WireGuard interface is UP""$reset"
    else
        echo "$red""✗ WireGuard interface exists but is DOWN""$reset"
    end
else
    echo "$red""✗ WireGuard interface doesn't exist!""$reset"
    echo "$yellow""Try manually creating it with: ip link add dev wireguard type wireguard""$reset"
end

echo ""
echo "$yellow""13. Testing Host Resolution:""$reset"
echo "$blue""DNS Server Configuration:""$reset"
uci -q get network.wireguard.dns || echo "$yellow""No DNS configured for WireGuard interface""$reset"

echo "$blue""Testing DNS resolution from router:""$reset"
nslookup google.com >/dev/null 2>&1
if test $status -eq 0
    echo "$green""✓ DNS resolution is working""$reset"
else
    echo "$red""✗ DNS resolution failed""$reset"
end

echo ""
echo "$yellow""14. Kernel Module Check:""$reset"
echo "$blue""WireGuard kernel module status:""$reset"
if lsmod | grep -q wireguard
    echo "$green""✓ WireGuard kernel module is loaded""$reset"
else
    echo "$red""✗ WireGuard kernel module is NOT loaded!""$reset"
    echo "$yellow""Try loading it with: modprobe wireguard""$reset"
end

echo ""
echo "$yellow""15. Quick Fixes (choose an option):""$reset"
echo "1) Restart WireGuard"
echo "2) Restart Network"
echo "3) Restart Firewall"
echo "4) Exit"
echo "$blue""Enter choice (1-4): ""$reset"
read quick_fix

switch $quick_fix
    case "1"
        echo "$blue""Restarting WireGuard...""$reset"
        ifdown wireguard
        sleep 2
        ifup wireguard
        echo "$green""WireGuard restarted. Check with 'wg show' to verify""$reset"
    case "2"
        echo "$blue""Restarting network...""$reset"
        /etc/init.d/network restart
        echo "$green""Network restarted. Allow a few seconds to reconnect.""$reset"
    case "3"
        echo "$blue""Restarting firewall...""$reset"
        /etc/init.d/firewall restart
        echo "$green""Firewall restarted.""$reset"
    case "*"
        echo "$green""No action taken.""$reset"
end

echo ""
echo "$green""Diagnostics complete.""$reset"
