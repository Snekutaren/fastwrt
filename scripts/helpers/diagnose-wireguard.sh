#!/usr/bin/fish
# WireGuard Connectivity Diagnostic Tool

# Source common color definitions if available
if test -f "$PROFILE_DIR/colors.fish"
    source "$PROFILE_DIR/colors.fish"
else
    # Define colors directly if not available
    set green (echo -e "\033[0;32m")
    set yellow (echo -e "\033[0;33m")
    set red (echo -e "\033[0;31m")
    set blue (echo -e "\033[0;34m")
    set reset (echo -e "\033[0m")
end

echo "$blue""----- WireGuard Connectivity Diagnostic Tool -----""$reset"

# Check if WireGuard is installed
echo "$blue""Checking WireGuard installation...""$reset"
if command -v wg >/dev/null 2>&1
    echo "$green""WireGuard tools installed""$reset"
else
    echo "$red""WireGuard tools not installed. Install with: opkg update && opkg install wireguard-tools""$reset"
    exit 1
end

# Check kernel module
echo "$blue""Checking WireGuard kernel module...""$reset"
if lsmod | grep -q wireguard
    echo "$green""WireGuard kernel module loaded""$reset"
else
    echo "$red""WireGuard kernel module not loaded""$reset"
    echo "$yellow""Attempting to load module...""$reset"
    modprobe wireguard
    if lsmod | grep -q wireguard
        echo "$green""Successfully loaded WireGuard kernel module""$reset"
    else
        echo "$red""Failed to load WireGuard kernel module. Install with: opkg update && opkg install kmod-wireguard""$reset"
    end
end

# Check UCI configuration
echo "$blue""Checking UCI configuration...""$reset"
if uci -q get network.wireguard > /dev/null
    echo "$green""WireGuard interface defined in UCI""$reset"
    
    # Check key configuration
    set has_private_key false
    set has_listen_port false
    set has_addresses false
    
    if test -n "$(uci -q get network.wireguard.private_key)"
        echo "$green""Private key configured""$reset"
        set has_private_key true
    else
        echo "$red""Private key missing""$reset"
    end
    
    if test -n "$(uci -q get network.wireguard.listen_port)"
        echo "$green""Listen port configured: ""$reset"(uci -q get network.wireguard.listen_port)
        set has_listen_port true
    else
        echo "$red""Listen port not configured""$reset"
    end
    
    if test -n "$(uci -q get network.wireguard.addresses)"
        echo "$green""Addresses configured: ""$reset"(uci -q get network.wireguard.addresses)
        set has_addresses true
    else
        echo "$red""Addresses not configured""$reset"
    end
    
    # Check peers
    set peer_count (uci show network | grep -c "=wireguard_wireguard")
    if test $peer_count -gt 0
        echo "$green""$peer_count WireGuard peers configured""$reset"
        
        # Show peer details
        set i 1
        for peer in (uci show network | grep "=wireguard_wireguard" | cut -d. -f2 | cut -d= -f1)
            echo "$blue""Peer $i:""$reset"
            echo "  Description: "(uci -q get network.$peer.description || echo "unnamed")
            echo "  Public Key: "(uci -q get network.$peer.public_key || echo "not set")
            echo "  Allowed IPs: "(uci -q get network.$peer.allowed_ips || echo "not set")
            echo "  Interface: "(uci -q get network.$peer.interface || echo "not set")
            set i (math $i + 1)
        end
    else
        echo "$red""No WireGuard peers configured""$reset"
    end
else
    echo "$red""WireGuard interface not defined in UCI""$reset"
end

# Check system-level interface
echo "$blue""Checking system-level WireGuard interface...""$reset"
if ip link show wireguard >/dev/null 2>&1
    echo "$green""WireGuard interface exists at system level""$reset"
    ip link show wireguard
    
    # Check if interface is up
    if ip link show wireguard | grep -q "UP"
        echo "$green""WireGuard interface is UP""$reset"
    else
        echo "$red""WireGuard interface is DOWN""$reset"
        echo "$yellow""Attempting to bring up interface...""$reset"
        ip link set wireguard up
    end
    
    # Check IP address
    echo "$blue""WireGuard IP address:""$reset"
    ip addr show wireguard | grep inet
    
    # Show WireGuard status
    echo "$blue""WireGuard status:""$reset"
    wg show wireguard
else
    echo "$red""WireGuard interface does not exist at system level""$reset"
    echo "$yellow""Attempting to create interface...""$reset"
    
    # Try to create interface
    ip link add dev wireguard type wireguard
    
    if test $status -eq 0
        echo "$green""WireGuard interface created successfully""$reset"
        
        # Configure from UCI
        set private_key (uci -q get network.wireguard.private_key)
        set listen_port (uci -q get network.wireguard.listen_port)
        set addresses (uci -q get network.wireguard.addresses)
        
        if test -n "$private_key"
            echo "$blue""Configuring private key...""$reset"
            echo "$private_key" > /tmp/wg_privkey
            wg set wireguard private-key /tmp/wg_privkey
            rm /tmp/wg_privkey
        end
        
        if test -n "$listen_port"
            echo "$blue""Configuring listen port...""$reset"
            wg set wireguard listen-port "$listen_port"
        end
        
        if test -n "$addresses"
            echo "$blue""Configuring IP address...""$reset"
            ip addr add "$addresses" dev wireguard
        end
        
        # Bring interface up
        ip link set wireguard up
        echo "$green""WireGuard interface configured and brought up""$reset"
    else
        echo "$red""Failed to create WireGuard interface. Check kernel module.""$reset"
    end
end

# Check firewall configuration
echo "$blue""Checking firewall configuration...""$reset"

# Check WireGuard zone
if uci -q get firewall.wireguard > /dev/null
    echo "$green""WireGuard zone exists""$reset"
    echo "  Network: "(uci -q get firewall.wireguard.network)
    echo "  Input: "(uci -q get firewall.wireguard.input)
    echo "  Output: "(uci -q get firewall.wireguard.output)
    echo "  Forward: "(uci -q get firewall.wireguard.forward)
else
    echo "$red""WireGuard zone not configured""$reset"
end

# Check port forwarding
if uci -q get firewall.port_forward_wan_to_wg > /dev/null
    echo "$green""WireGuard port forwarding rule exists""$reset"
    echo "  Port: "(uci -q get firewall.port_forward_wan_to_wg.src_dport)
    echo "  Protocol: "(uci -q get firewall.port_forward_wan_to_wg.proto)
    echo "  Destination IP: "(uci -q get firewall.port_forward_wan_to_wg.dest_ip)
    echo "  Enabled: "(uci -q get firewall.port_forward_wan_to_wg.enabled)
else
    echo "$red""WireGuard port forwarding rule not configured""$reset"
end

# Check direct allow rule
if uci -q get firewall.allow_wireguard_port > /dev/null
    echo "$green""WireGuard direct allow rule exists""$reset"
else
    echo "$red""WireGuard direct allow rule not configured""$reset"
    echo "$yellow""Consider adding an explicit allow rule for UDP port 52018""$reset"
end

# Check forwarding rules
if uci -q get firewall.forward_wg_to_wan > /dev/null
    echo "$green""WireGuard to WAN forwarding rule exists""$reset"
else
    echo "$red""WireGuard to WAN forwarding rule missing""$reset"
end

# Check IP forwarding
echo "$blue""Checking IP forwarding...""$reset"
set ip_forward (cat /proc/sys/net/ipv4/ip_forward)
if test "$ip_forward" = "1"
    echo "$green""IP forwarding is enabled""$reset"
else
    echo "$red""IP forwarding is disabled - enabling now""$reset"
    echo 1 > /proc/sys/net/ipv4/ip_forward
end

# Check port accessibility with netstat
echo "$blue""Checking WireGuard port status...""$reset"
if command -v netstat >/dev/null 2>&1
    if netstat -lnpu | grep -q ":52018"
        echo "$green""WireGuard port 52018 is open and listening""$reset"
        netstat -lnpu | grep ":52018"
    else
        echo "$red""WireGuard port 52018 is not listening""$reset"
        echo "$yellow""Check if WireGuard is properly configured and running""$reset"
    end
else
    echo "$yellow""netstat not available, skipping port check""$reset"
end

echo "$blue""----- Diagnostic Complete -----""$reset"
echo "$yellow""If issues persist, run the repair script: repair-wireguard""$reset"
echo "$yellow""For additional help, check the log files in /tmp/fastwrt_logs/""$reset"
