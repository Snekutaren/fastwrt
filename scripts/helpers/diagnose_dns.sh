#!/usr/bin/fish
# DNS Diagnostic Script for FastWrt

source "$PROFILE_DIR/colors.fish" 2>/dev/null || begin
    # Define colors if not available from profile
    set green (echo -e "\033[0;32m")
    set yellow (echo -e "\033[0;33m")
    set red (echo -e "\033[0;31m")
    set blue (echo -e "\033[0;34m")
    set purple (echo -e "\033[0;35m")
    set reset (echo -e "\033[0m")
end

echo "$purple""Running DNS diagnostics...""$reset"
echo "$purple""---------------------------""$reset"

# Check if dnsmasq was restarted during script execution
echo "$blue""Checking dnsmasq uptime:""$reset"
set dnsmasq_pid (pgrep dnsmasq)
if test -n "$dnsmasq_pid"
    echo "$yellow""dnsmasq process ID: $dnsmasq_pid""$reset"
    echo "$yellow""dnsmasq running since: ""$reset"(ps -o etime= -p $dnsmasq_pid)
else
    echo "$red""dnsmasq is not running!""$reset"
end
echo ""

# Check DNS configuration
echo "Current DNS configuration:"
uci show dhcp | grep dnsmasq
echo ""

# Check system resolv.conf
echo "System resolv.conf:"
cat /tmp/resolv.conf.d/resolv.conf.auto
echo ""

# Check DNS listening status
echo "DNS listening status:"
netstat -tulpn | grep :53
echo ""

# Check firewall rules affecting DNS
echo "Firewall rules affecting DNS:"
uci show firewall | grep -i dns
uci show firewall | grep 53
echo ""

# Test DNS resolution
echo "Testing DNS resolution:"
nslookup google.com 127.0.0.1
echo ""

# Examine DNS service logs
echo "Recent dnsmasq logs:"
logread | grep dnsmasq | tail -20
echo ""

# Check for service restarts in log
echo "$blue""Checking for service restarts:""$reset"
logread | grep -E 'dnsmasq|restart|init.d' | tail -20
echo ""

# Check DNS forwarding status
echo "$blue""DNS forwarding status:""$reset"
uci show dhcp.@dnsmasq[0].domain_needed
uci show dhcp.@dnsmasq[0].localise_queries
uci show dhcp.@dnsmasq[0].rebind_protection
echo ""

echo "$green""DNS diagnostics complete""$reset"

# Add test command to reset DNS service safely
echo "$purple""To reset DNS service:""$reset"
echo "$yellow""1. Run: /etc/init.d/dnsmasq restart""$reset"
echo "$yellow""2. Wait a few seconds""$reset"
echo "$yellow""3. Try to resolve: nslookup google.com""$reset"
