#!/usr/bin/fish
# FastWrt Port Exposure Diagnostic Tool
# This script analyzes why ports might be exposed despite firewall rules

# Set colors for better readability
set green (echo -e "\033[0;32m")
set yellow (echo -e "\033[0;33m")
set red (echo -e "\033[0;31m")
set blue (echo -e "\033[0;34m")
set purple (echo -e "\033[0;35m")
set reset (echo -e "\033[0m")

echo "$purple""FastWrt Port Exposure Diagnostic Tool""$reset"
echo "$blue""Gathering information to determine why ports appear open...""$reset"

# Section 1: Check service bindings (MOST CRITICAL)
echo "$yellow""1. Checking service bindings (listening addresses)...""$reset"

# Check all listening TCP ports
echo "$blue""TCP ports listening on ALL interfaces (0.0.0.0):""$reset"
netstat -lnt | grep "0.0.0.0" | sort

# Specifically check web server binding
echo "$blue""Web server (uhttpd) binding:""$reset"
uci show uhttpd.main.listen_http
uci show uhttpd.main.listen_https

# Check process list for running services that could be binding to all interfaces
echo "$blue""Running processes that could be binding to all interfaces:""$reset"
ps | grep -E "uhttpd|dropbear|nginx|miniupnpd|dnsmasq" | grep -v grep

# Section 2: Check firewall rules and their precedence
echo "$yellow""2. Examining firewall rules and their precedence...""$reset"

# Get rules that might affect HTTP/HTTPS
echo "$blue""Firewall rules affecting web ports (80/443):""$reset"
uci show firewall | grep -E "src.*wan.*dest_port.*(80|443|http|https)" | sort

# Check for conflicting rules with higher priority
echo "$blue""Rules with high priority (lower numbers have higher priority):""$reset"
uci show firewall | grep "priority" | sort

# Section 3: Check for port forwarding/redirection rules
echo "$yellow""3. Checking for port forwarding rules...""$reset"
uci show firewall | grep -E "redirect|DNAT" | grep -v "src_dport"

# Check UPnP status and rules
echo "$blue""UPnP status and auto-created rules:""$reset"
if [ -f /etc/init.d/miniupnpd ]; then
    echo "UPnP service exists on system"
    /etc/init.d/miniupnpd enabled && echo "UPnP is enabled" || echo "UPnP is disabled"
    [ -f /var/etc/upnp.leases ] && cat /var/etc/upnp.leases || echo "No UPnP leases found"
else
    echo "UPnP not installed"
end

# Section 4: Check interface-to-zone mappings
echo "$yellow""4. Verifying network interfaces and zone assignments...""$reset"

# Get all zones and their networks
echo "$blue""Firewall zones and their assigned networks:""$reset"
uci show firewall | grep "\.network="

# List all network interfaces and their assignments
echo "$blue""Network interface configuration:""$reset"
uci show network | grep -E "device=|ifname="

# Section 5: Check for IPv6 issues
echo "$yellow""5. Checking IPv6 configuration...""$reset"
echo "$blue""IPv6 enabled status:""$reset"
uci get network.wan.ipv6

echo "$blue""IPv6 addresses on interfaces:""$reset"
ip -6 addr

echo "$blue""IPv6 firewall rules:""$reset"
uci show firewall | grep "family='ipv6'"

# Raw iptables check
echo "$yellow""6. Checking raw iptables rules...""$reset"
echo "$blue""IPv4 iptables rules (input chain):""$reset"
iptables -L INPUT -n

echo "$blue""IPv6 ip6tables rules (input chain):""$reset"
ip6tables -L INPUT -n 2>/dev/null || echo "ip6tables not available"

# Final summary with likely issues
echo ""
echo "$purple""ANALYSIS SUMMARY""$reset"
echo "$yellow""Potential issues based on diagnostic data:""$reset"

# Check for the most critical issue - uhttpd binding to 0.0.0.0
if netstat -lnt | grep -q "0.0.0.0:80"; or netstat -lnt | grep -q "0.0.0.0:443"
    echo "$red""CRITICAL ISSUE: Web server (uhttpd) is binding to ALL interfaces (0.0.0.0)""$reset"
    echo "$red""This exposes your web interface to the internet even with firewall rules!""$reset"
    echo "$yellow""SOLUTION: Configure uhttpd to bind ONLY to internal IPs (10.0.0.1, 127.0.0.1)""$reset"
    echo "$yellow""  Run: uci -q delete uhttpd.main.listen_http""$reset"
    echo "$yellow""  Run: uci add_list uhttpd.main.listen_http='10.0.0.1:80'""$reset"
    echo "$yellow""  Run: uci add_list uhttpd.main.listen_http='127.0.0.1:80'""$reset"
    echo "$yellow""  Run: uci commit uhttpd; /etc/init.d/uhttpd restart""$reset"
end

# Check for lack of explicit block rules
if not uci show firewall | grep -q "dest_port.*80.*DROP"
    echo "$yellow""ISSUE: No explicit rule to DROP traffic to port 80 from WAN""$reset"
    echo "$yellow""Add high-priority DROP rules for ports 80 and 443 from WAN""$reset"
end

# Check for any other services listening on 0.0.0.0
set other_exposed (netstat -lnt | grep "0.0.0.0:" | grep -v -E ":80|:443" | awk '{print $4}' | cut -d: -f2)
if test -n "$other_exposed"
    echo "$red""OTHER EXPOSED SERVICES: Found services listening on all interfaces (0.0.0.0)""$reset"
    echo "$red""Ports: $other_exposed""$reset"
    echo "$yellow""Check each of these services and reconfigure them to bind only to internal interfaces""$reset"
end

echo ""
echo "$blue""Use the output above to identify and fix the source of port exposure issues.""$reset"
echo "$blue""After applying fixes, rerun this script and/or use an external port scanning service to verify.""$reset"
