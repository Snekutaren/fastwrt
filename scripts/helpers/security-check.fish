#!/usr/bin/fish
# FastWrt Security Audit Tool
# This script checks for common security issues in the router configuration

# Set colors for better readability
set green (echo -e "\033[0;32m")
set yellow (echo -e "\033[0;33m")
set red (echo -e "\033[0;31m")
set blue (echo -e "\033[0;34m")
set purple (echo -e "\033[0;35m")
set reset (echo -e "\033[0m")

echo "$purple""FastWrt Security Audit Tool""$reset"
echo "$blue""Checking for potential security issues...""$reset"

# Check WAN policies
echo "$yellow""1. Checking WAN zone policies...""$reset"
set wan_input (uci -q get firewall.wan_zone.input)
set wan_output (uci -q get firewall.wan_zone.output)
set wan_forward (uci -q get firewall.wan_zone.forward)

if test "$wan_input" = "ACCEPT"
    echo "$red""CRITICAL: WAN input policy is set to ACCEPT! Should be DROP.""$reset"
else
    echo "$green""✓ WAN input policy correctly set to $wan_input""$reset"
end

if test "$wan_output" != "ACCEPT"
    echo "$red""WARNING: WAN output policy is $wan_output! Should be ACCEPT to prevent internet loss.""$reset"
else
    echo "$green""✓ WAN output policy correctly set to ACCEPT""$reset"
end

# Check for web access from WAN
echo "$yellow""2. Checking for web access rules...""$reset"
set http_allow_rules (uci show firewall | grep -E "src.*wan.*dest_port.*(80|443).*target.*ACCEPT" | cut -d. -f1-2)

if test -n "$http_allow_rules"
    echo "$red""CRITICAL: Found rules allowing web access from WAN:""$reset"
    for rule in $http_allow_rules
        echo "$red""  $rule: "(uci show $rule | tr '\n' ' ')"$reset"
    end
else
    echo "$green""✓ No rules allowing web access from WAN""$reset"
end

# Check for open ports on WAN
echo "$yellow""3. Checking for open ports on WAN...""$reset"
echo "$blue""Testing HTTP accessibility...""$reset"
nc -z -w1 localhost 80
if test $status -eq 0
    echo "$blue""  HTTP server is running locally""$reset"
    
    # Test if port is accessible from WAN by checking rule
    set block_rule (uci show firewall | grep -E "src.*wan.*dest_port.*80.*target.*DROP" | wc -l)
    if test $block_rule -eq 0
        echo "$red""  WARNING: No rule explicitly blocking WAN access to HTTP (port 80)""$reset"
    else
        echo "$green""  ✓ Found rule blocking WAN access to HTTP""$reset"
    end
else
    echo "$green""  ✓ HTTP server not running locally""$reset"
end

# Check external exposure with nmap
echo "$yellow""4. Testing for externally exposed services...""$reset"
echo "$blue""This would require an actual external scan. Consider using:""$reset"
echo "$blue""  - https://www.shodan.io/ to check if your IP has exposed services""$reset"
echo "$blue""  - https://www.grc.com/shieldsup to test your firewall from outside""$reset"
echo "$blue""  - https://www.canyouseeme.org/ to check specific ports""$reset"

# Check SSH configuration
echo "$yellow""5. Checking SSH configuration...""$reset"
set ssh_wan_access (uci show firewall | grep -E "src.*wan.*dest_port.*(22|6622).*target.*ACCEPT" | wc -l)
set ssh_password_auth (uci -q get dropbear.@dropbear[0].PasswordAuth)

if test $ssh_wan_access -gt 0
    echo "$red""CRITICAL: SSH may be accessible from WAN! This is a security risk.""$reset"
else
    echo "$green""✓ No rules allowing SSH access from WAN""$reset"
end

if test "$ssh_password_auth" = "on"
    echo "$yellow""WARNING: SSH password authentication is enabled""$reset"
    echo "$yellow""  Consider using key-based authentication only by setting PasswordAuth to 'off'""$reset"
else
    echo "$green""✓ SSH password authentication is disabled, using key-based auth""$reset"
end

# Final security advice
echo "$purple""Security Audit Complete""$reset"
echo "$yellow""Recommendations:""$reset"
echo "1. Always access your router's web interface through WireGuard VPN"
echo "2. Regularly check for unauthorized access attempts in logs"
echo "3. Keep your router firmware updated"
echo "4. Consider running an external port scan monthly to verify security"

echo "$blue""Run this tool regularly to check your router's security posture""$reset"
