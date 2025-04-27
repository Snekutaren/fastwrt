#!/usr/bin/fish
# Helper script to debug WireGuard connectivity issues

# Source colors from profile directory or use defaults
set COLORS_FILES "$PROFILE_DIR/colors.fish" "$DEFAULTS_DIR/colors.fish" "$CONFIG_DIR/colors.fish" "$BASE_DIR/colors.fish" "$BASE_DIR/scripts/etc/uci-defaults/config/profiles/sne/colors.fish"
for file_path in $COLORS_FILES
    if test -f "$file_path"
        source "$file_path"
        break
    end
end

# Fallback if colors not loaded
if not set -q green
    set green (echo -e "\033[0;32m")
    set yellow (echo -e "\033[0;33m")
    set red (echo -e "\033[0;31m")
    set blue (echo -e "\033[0;34m")
    set purple (echo -e "\033[0;35m")
    set reset (echo -e "\033[0m")
end

echo "$purple""WireGuard Debug Tool""$reset"
echo "$blue""Checking WireGuard status...""$reset"

# Check if WireGuard interface exists
if not ip link show wireguard > /dev/null 2>&1
    echo "$red""WireGuard interface not found!""$reset"
    echo "$yellow""Try running: /usr/bin/repair-wireguard""$reset"
    exit 1
end

# Show WireGuard interface details
echo "$blue""WireGuard interface details:""$reset"
ip link show wireguard
ip addr show wireguard

# Check WireGuard configuration
echo "$blue""WireGuard configuration:""$reset"
wg show wireguard

# Check firewall forwarding rules
echo "$blue""Checking firewall forwarding rules:""$reset"
uci show firewall | grep forward | grep wireguard

# Check IP forwarding settings
echo "$blue""IP forwarding settings:""$reset"
sysctl net.ipv4.ip_forward

# Try ping from WireGuard interface
echo "$blue""Attempting to ping 1.1.1.1 from router:""$reset"
ping -c 3 -I wireguard 1.1.1.1

# Check WireGuard route
echo "$blue""WireGuard routing:""$reset"
ip route | grep wireguard

# Check for NAT rules
echo "$blue""NAT rules:""$reset"
iptables -t nat -L -n -v | grep -E 'wireguard|10.255'

# Suggest fixes
echo "$yellow""
Possible fixes to try:
1. Check if your WireGuard client configuration includes:
   - Server's public key: wg show wireguard public-key
   - Correct AllowedIPs: 0.0.0.0/0, ::/0
   - Correct endpoint: YOUR_PUBLIC_IP:52018
   
2. On the router, verify:
   - IP forwarding is enabled (should be 1): sysctl net.ipv4.ip_forward
   - Firewall forwarding from wireguard to wan is enabled
   - WireGuard peer allowed_ips includes 0.0.0.0/0
   
3. Restart services:
   - /etc/init.d/network restart
   - /etc/init.d/firewall restart
""$reset"

echo "$green""Debug information collection complete.""$reset"

chmod +x "$script_path"
