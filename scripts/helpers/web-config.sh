#!/usr/bin/fish
# FastWrt Web Interface Configuration - Implementation using fish shell

# Source common color definitions
source "$PROFILE_DIR/colors.fish"

# Log the purpose of the script
print_start "Configuring web interface security settings..."

# Restrict uhttpd to only listen on LAN interfaces
echo "$blue""Restricting web interface to internal networks only...""$reset"
uci -q delete uhttpd.main.listen_http
uci -q delete uhttpd.main.listen_https

# Only bind to LAN IP addresses, not to WAN or 0.0.0.0
uci add_list uhttpd.main.listen_http='10.0.0.1:80'
uci add_list uhttpd.main.listen_http='10.255.0.1:80'
uci add_list uhttpd.main.listen_http='127.0.0.1:80'
# Add HTTPS only on internal interfaces
uci add_list uhttpd.main.listen_https='10.0.0.1:443'
uci add_list uhttpd.main.listen_https='10.255.0.1:443'
uci add_list uhttpd.main.listen_https='127.0.0.1:443'

echo "$green""Web interface now restricted to internal networks only""$reset"
print_success "Web interface security configuration completed."
