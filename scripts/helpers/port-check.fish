#!/usr/bin/fish
# FastWrt Port Security Checker
# This script checks which ports are actually listening and on which interfaces

# Set colors for better readability
set green (echo -e "\033[0;32m")
set yellow (echo -e "\033[0;33m")
set red (echo -e "\033[0;31m")
set blue (echo -e "\033[0;34m")
set purple (echo -e "\033[0;35m")
set reset (echo -e "\033[0m")

echo "$purple""FastWrt Port Security Checker""$reset"
echo "$blue""Checking for listening ports and interfaces...""$reset"

# Critical ports to check
set critical_ports 22 53 80 443 6622 52018

echo "$yellow""1. Checking all listening ports...""$reset"

# Get listening TCP ports
echo "$blue""TCP listening ports:""$reset"
netstat -lnt | grep LISTEN | sort -n -k 4

# Get listening UDP ports (more difficult with netstat)
echo "$blue""UDP listening ports:""$reset"
netstat -lnu | sort -n -k 4

# Check binding interfaces for critical services
echo "$yellow""2. Checking critical services for binding interfaces...""$reset"

# Check HTTP server (uhttpd)
echo "$blue""Web server (uhttpd) binding:""$reset"
ps | grep uhttpd | grep -v grep
echo "$blue""uhttpd configuration:""$reset"
uci show uhttpd.main.listen_http
uci show uhttpd.main.listen_https

# Check SSH server (dropbear)
echo "$blue""SSH server (dropbear) binding:""$reset"
ps | grep dropbear | grep -v grep
echo "$blue""dropbear configuration:""$reset"
uci show dropbear.@dropbear[0].Interface
uci show dropbear.@dropbear[0].Port

# Check DNS server (dnsmasq)
echo "$blue""DNS server (dnsmasq) binding:""$reset"
ps | grep dnsmasq | grep -v grep

# Check WireGuard
echo "$blue""WireGuard binding:""$reset"
ip addr show wireguard

echo "$yellow""3. Advanced port exposure test...""$reset"
echo "$blue""Running exposure test for common ports:""$reset"

for port in $critical_ports
    # For TCP
    echo -n "TCP port $port: "
    if nc -z -w1 localhost $port 2>/dev/null
        set listeners (netstat -lnt | grep ":$port" | awk '{print $4}' | cut -d: -f1)
        if string match -q "0.0.0.0" "$listeners"
            echo "$red""EXPOSED - Listening on all interfaces (0.0.0.0)""$reset"
        else
            echo "$green""Listening only on specific interfaces: $listeners""$reset"
        end
    else
        echo "$green""Not listening""$reset"
    end
    
    # For UDP (limited info available)
    echo -n "UDP port $port: "
    if nc -zu -w1 localhost $port 2>/dev/null
        set listeners (netstat -lnu | grep ":$port" | awk '{print $4}' | cut -d: -f1)
        if string match -q "0.0.0.0" "$listeners"
            echo "$red""EXPOSED - Listening on all interfaces (0.0.0.0)""$reset"
        else
            echo "$green""Listening only on specific interfaces: $listeners""$reset"
        end
    else
        echo "$green""Not listening""$reset"
    end
end

echo "$yellow""4. Checking firewall rules for exposed ports...""$reset"
for port in 80 443
    echo "$blue""Checking port $port protection:""$reset"
    
    # Check for explicit DROP rules for this port
    set drop_rules (uci show firewall | grep -E "dest_port.*$port.*DROP" | wc -l)
    
    if test $drop_rules -eq 0
        echo "$red""WARNING: No explicit DROP rules found for port $port from WAN""$reset"
    else
        echo "$green""Found $drop_rules DROP rules for port $port""$reset"
    end
    
    # Check rule priorities
    set rule_priorities (uci show firewall | grep -E "dest_port.*$port.*DROP" | grep -o "priority='[0-9]*'" | sort)
    echo "$blue""Rule priorities for port $port: $rule_priorities""$reset"
end

echo ""
echo "$purple""Security Check Complete""$reset"
echo "$yellow""Recommendations:""$reset"
echo "1. Ensure web server (uhttpd) binds ONLY to internal IPs (10.0.0.1, 127.0.0.1) not 0.0.0.0"
echo "2. Configure explicit DROP rules for ports 80/443 from WAN with high priority (1-5)"
echo "3. Run this check after any configuration change to verify security"
