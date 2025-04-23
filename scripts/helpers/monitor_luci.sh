#!/usr/bin/fish
# Enhanced script to monitor what happens when creating wireless networks in LuCI
# Run this script before attempting to create or save a new SSID in LuCI

echo "Starting enhanced LuCI monitoring for wireless network creation issues..."
echo "Timestamp: "(date)
echo "---------------------------------------------"

# First, enable more verbose logging
echo "Enabling verbose logging for LuCI and network services..."
uci set system.@system[0].log_size='512'
uci set system.@system[0].log_level='7'  # Debug level
uci commit system
/etc/init.d/log restart

# Enable LuCI debug mode if possible
if test -f /etc/config/luci
    echo "Enabling LuCI debug mode..."
    uci set luci.main.debuglevel='3'  # Maximum debug level
    uci commit luci
    /etc/init.d/uhttpd restart
end

# Function to show current state of relevant configurations
function show_current_state
    echo "=== NETWORK INTERFACES ==="
    ip link | grep -v "lo:" | grep mtu
    
    echo
    echo "=== NETWORK UCI CONFIG ==="
    uci show network | sort
    
    echo
    echo "=== WIRELESS UCI CONFIG ==="
    uci show wireless | sort
    
    echo 
    echo "=== FIREWALL ZONES ==="
    uci show firewall | grep -E "firewall\..+\.name|firewall\..+\.network" | sort
    
    echo
    echo "=== DHCP CONFIG ==="
    uci show dhcp | grep -E "dhcp\..+\.interface" | sort
    
    echo
    echo "=== NETWORK INTERFACE STATUS ==="
    ifconfig | grep -E "^[a-zA-Z]"
    
    echo
    echo "=== WIFI STATUS ==="
    wifi status
    
    echo
    echo "=== RECENT SYSLOG ENTRIES ==="
    logread | tail -n 30
    
    echo
    echo "=== LUCI SESSION FILES ==="
    ls -la /tmp/luci-* 2>/dev/null || echo "No LuCI session files found"
    
    echo
    echo "=== UHTTPD STATUS ==="
    ps | grep uhttpd
    
    echo
    echo "=== ACTIVE CONNECTIONS ==="
    netstat -tunap | grep -E '(80|443)'
end

# Initial state capture
echo "CAPTURING INITIAL STATE..."
show_current_state > /tmp/wireless_initial_state.log
echo "Initial state captured to /tmp/wireless_initial_state.log"

# Save initial UCI configuration for comparison
echo "Saving initial UCI configurations for comparison..."
uci export network > /tmp/network_before.uci
uci export wireless > /tmp/wireless_before.uci
uci export firewall > /tmp/firewall_before.uci

echo
echo "MONITORING FOR CHANGES... (Press Ctrl+C to stop)"
echo "Try to create your SSID in LuCI now."
echo "Step 1: Open wireless settings and add a new wireless network"
echo "Step 2: Configure it and assign to 'core' network"
echo "Step 3: Try to save and note if save button is disabled or if there's an error"

# Set up a tmpfile for changes
set changes_file /tmp/luci_wireless_changes.log
touch $changes_file

# Monitor LuCI request log if it exists
if test -f /tmp/luci_request.log
    tail -f /tmp/luci_request.log &
    set luci_pid $last_pid
end

# Create a file monitor to watch for UCI changes
touch /tmp/last_check_time
set last_check_time (date +%s)

while true
    # Check system logs for relevant changes
    echo -n "." >&2
    
    # Look for relevant messages in logs
    if logread -l 50 | grep -E 'luci|wireless|network|uhttpd|nginx|firewall' > /tmp/recent_changes.log
        if test -s /tmp/recent_changes.log  # If file is not empty
            echo >> $changes_file
            echo "CHANGE DETECTED IN LOGS at "(date)":" >> $changes_file
            cat /tmp/recent_changes.log >> $changes_file
            echo >> $changes_file
        end
    end
    
    # Check for UCI configuration changes
    uci export network > /tmp/network_current.uci
    uci export wireless > /tmp/wireless_current.uci
    uci export firewall > /tmp/firewall_current.uci
    
    if not cmp -s /tmp/network_before.uci /tmp/network_current.uci
        echo >> $changes_file
        echo "CHANGE DETECTED IN NETWORK CONFIG at "(date)":" >> $changes_file
        diff -u /tmp/network_before.uci /tmp/network_current.uci >> $changes_file
        cp /tmp/network_current.uci /tmp/network_before.uci
    end
    
    if not cmp -s /tmp/wireless_before.uci /tmp/wireless_current.uci
        echo >> $changes_file
        echo "CHANGE DETECTED IN WIRELESS CONFIG at "(date)":" >> $changes_file
        diff -u /tmp/wireless_before.uci /tmp/wireless_current.uci >> $changes_file
        cp /tmp/wireless_current.uci /tmp/wireless_before.uci
    end
    
    if not cmp -s /tmp/firewall_before.uci /tmp/firewall_current.uci
        echo >> $changes_file
        echo "CHANGE DETECTED IN FIREWALL CONFIG at "(date)":" >> $changes_file
        diff -u /tmp/firewall_before.uci /tmp/firewall_current.uci >> $changes_file
        cp /tmp/firewall_current.uci /tmp/firewall_before.uci
    end
    
    # Check if HTTP requests are happening
    if test -f /var/log/nginx/access.log
        if grep -q (date +"%d/%b/%Y") /var/log/nginx/access.log
            echo >> $changes_file
            echo "NGINX ACCESS LOG ACTIVITY at "(date)":" >> $changes_file
            tail -n 5 /var/log/nginx/access.log >> $changes_file
        end
    end

    if test -f /var/log/uhttpd.log
        if grep -q (date +"%Y-%m-%d") /var/log/uhttpd.log
            echo >> $changes_file
            echo "UHTTPD LOG ACTIVITY at "(date)":" >> $changes_file
            tail -n 5 /var/log/uhttpd.log >> $changes_file
        end
    end
    
    # Check for LuCI temporary files
    set current_time (date +%s)
    if test (math $current_time - $last_check_time) -ge 5  # Every 5 seconds
        set last_check_time $current_time
        
        # Look for recently modified LuCI files
        if find /tmp -name "luci-*" -mmin -1 | grep -q .
            echo >> $changes_file
            echo "RECENTLY MODIFIED LUCI FILES at "(date)":" >> $changes_file
            find /tmp -name "luci-*" -mmin -1 -ls >> $changes_file
        end
        
        # Check if any new HTTP sessions were created
        if ls -la /tmp/luci-sessions* 2>/dev/null | grep -q .
            echo >> $changes_file
            echo "CURRENT LUCI SESSIONS at "(date)":" >> $changes_file
            ls -la /tmp/luci-sessions* >> $changes_file
        end
    end
    
    # Check if we got any interesting changes and display notification
    if test -s $changes_file
        echo
        echo "Changes detected! See $changes_file for details."
        echo "Press Enter to view the changes, or wait for more changes..."
        echo
        
        # Clear the changes file after notifying
        cat $changes_file > /tmp/all_wireless_changes.log
        echo "" > $changes_file
    end
    
    # Sleep briefly to avoid excessive CPU usage
    sleep 1
end