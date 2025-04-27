#!/usr/bin/fish
# Helper script to fix missing allowed_ips in WireGuard configurations

# Source common color definitions
source "$PROFILE_DIR/colors.fish"

print_header "WireGuard Peer Fix Tool"
print_start "Checking for peers with missing allowed_ips..."

# Get list of WireGuard peer sections
set peer_sections (uci show network | grep "=wireguard_peer" | cut -d'=' -f1)

# Counter for fixed peers
set fixed_count 0

for section in $peer_sections
    # Get current allowed_ips setting
    set allowed_ips (uci -q get "$section.allowed_ips")
    set public_key (uci -q get "$section.public_key")
    set description (uci -q get "$section.description" || echo "Unknown peer")
    
    echo "$yellow""Checking peer: $description""$reset"
    
    # Check if allowed_ips is missing or doesn't include 0.0.0.0/0
    if test -z "$allowed_ips"; or not string match -q "*0.0.0.0/0*" "$allowed_ips"
        echo "$red""Peer $description has invalid allowed_ips: '$allowed_ips'""$reset"
        
        # Get client IP if available
        set client_ip ""
        
        # Try to determine client IP based on description
        switch (string lower "$description")
            case "*s10*"
                if set -q WG_CLIENT_IP_S10
                    set client_ip "$WG_CLIENT_IP_S10"
                else
                    set client_ip "10.255.0.2" # Default fallback for S10
                end
            case "*rog*"
                if set -q WG_CLIENT_IP_ROG
                    set client_ip "$WG_CLIENT_IP_ROG"
                else
                    set client_ip "10.255.0.3" # Default fallback for ROG
                end
            case "*"
                # Try to extract from existing allowed_ips
                if string match -q "*10.255.0*" "$allowed_ips"
                    set client_ip (string match -r '10\.255\.0\.[0-9]+' "$allowed_ips")
                else
                    # Ask user for client IP
                    echo "$yellow""Cannot determine client IP automatically. Please enter:""$reset"
                    read -P "Client IP (10.255.0.x): " client_ip
                    
                    # Apply default prefix if user only entered the last octet
                    if string match -q -r '^[0-9]+$' "$client_ip"
                        set client_ip "10.255.0.$client_ip"
                    end
                end
        end
        
        if test -z "$client_ip"
            echo "$red""Could not determine client IP for peer $description. Skipping.""$reset"
            continue
        end
        
        # Fix the allowed_ips
        echo "$blue""Setting allowed_ips for peer $description to \"$client_ip/32, 0.0.0.0/0\"...""$reset"
        uci set "$section.allowed_ips=$client_ip/32, 0.0.0.0/0"
        
        # Make sure route_allowed_ips is set
        uci set "$section.route_allowed_ips=1"
        
        # Ensure persistent_keepalive is set
        if not uci -q get "$section.persistent_keepalive" > /dev/null
            uci set "$section.persistent_keepalive=25"
        end
        
        set fixed_count (math $fixed_count + 1)
    else
        echo "$green""Peer $description has correct allowed_ips: $allowed_ips""$reset"
    end
end

if test $fixed_count -gt 0
    echo "$green""Fixed $fixed_count peers. Committing changes...""$reset"
    uci commit network
    
    echo "$blue""Restarting WireGuard interface...""$reset"
    ifdown wireguard
    ifup wireguard
    
    echo "$yellow""You may need to restart the firewall as well:""$reset"
    echo "   /etc/init.d/firewall restart"
    
    echo "$green""Peer configuration updated. Clients should now have internet access.""$reset"
else
    echo "$green""No peers needed fixing.""$reset"
end

# Final instructions
echo "$blue""Testing connectivity from a peer:""$reset"
echo "$yellow""After restarting WireGuard, clients should be able to access the internet.""$reset"
echo "$yellow""If issues persist, check firewall forwarding rules:""$reset"
echo "   uci show firewall | grep forward | grep wireguard"
