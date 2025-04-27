#!/usr/bin/fish
# FastWrt Web Security Fix - Critical binding issue correction

# Source common color definitions
source "$PROFILE_DIR/colors.fish"

# Ensure the script runs from its own directory
print_start "Applying critical web server security fix"

echo "$red""CRITICAL SECURITY ISSUE: Web server may be exposed to the internet!""$reset"
echo "$blue""Restricting web interface to internal IPs only...""$reset"

# 1. Fix uhttpd binding - MOST CRITICAL PART
echo "$yellow""Step 1: Configuring uhttpd to bind only to internal interfaces...""$reset"
uci -q delete uhttpd.main.listen_http
uci -q delete uhttpd.main.listen_https

# Add LAN and loopback only - NEVER bind to 0.0.0.0 (all interfaces)
uci add_list uhttpd.main.listen_http='10.0.0.1:80'
uci add_list uhttpd.main.listen_http='127.0.0.1:80'
uci add_list uhttpd.main.listen_https='10.0.0.1:443'
uci add_list uhttpd.main.listen_https='127.0.0.1:443'

# 2. Add highest priority block rules
echo "$yellow""Step 2: Adding highest priority firewall rules to block web access from WAN...""$reset"
# Block HTTP with absolute highest priority
uci set firewall.block_http_wan='rule'
uci set firewall.block_http_wan.name='Block-HTTP-From-WAN'
uci set firewall.block_http_wan.src='wan'
uci set firewall.block_http_wan.proto='tcp'
uci set firewall.block_http_wan.dest_port='80'
uci set firewall.block_http_wan.target='DROP'
uci set firewall.block_http_wan.enabled='1'
uci set firewall.block_http_wan.priority='1'  # Absolute highest priority

# Block HTTPS with absolute highest priority
uci set firewall.block_https_wan='rule'
uci set firewall.block_https_wan.name='Block-HTTPS-From-WAN'
uci set firewall.block_https_wan.src='wan'
uci set firewall.block_https_wan.proto='tcp'
uci set firewall.block_https_wan.dest_port='443'
uci set firewall.block_https_wan.target='DROP'
uci set firewall.block_https_wan.enabled='1'
uci set firewall.block_https_wan.priority='1'  # Absolute highest priority

# 3. Apply changes immediately for security (don't wait for central commit)
echo "$yellow""Step 3: Applying critical security changes immediately...""$reset"
uci commit uhttpd
/etc/init.d/uhttpd restart

uci commit firewall
/etc/init.d/firewall reload

echo "$green""SECURITY FIX APPLIED:""$reset"
echo "$green""1. Web server now only listens on internal interfaces""$reset"
echo "$green""2. Added highest-priority firewall rules to block web access from WAN""$reset"
echo "$green""3. Restarted services to apply changes immediately""$reset"

echo "$yellow""IMPORTANT: Please verify fix with an external port scan to confirm ports are no longer exposed""$reset"
print_success "Critical security fix completed."
