#!/usr/bin/fish
# FastWrt Configuration Fix Script
# This script helps identify and fix common configuration issues

# Set colors for better readability
set green (echo -e "\033[0;32m")
set yellow (echo -e "\033[0;33m")
set red (echo -e "\033[0;31m")
set blue (echo -e "\033[0;34m")
set purple (echo -e "\033[0;35m")
set reset (echo -e "\033[0m")

echo "$purple""FastWrt Configuration Fix Tool""$reset"
echo "$blue""Current time: ""$reset"(date)

# Check for root privileges
if test (id -u) -ne 0
    echo "$red""Please run as root""$reset"
    exit 1
end

# Function to fix negative entries in UCI changes
function fix_negative_entries
    echo "$purple""Checking for problematic negative entries in UCI changes...""$reset"
    set invalid_entries (uci changes | grep "^-" | sort -u)
    
    if test (count $invalid_entries) -gt 0
        echo "$red""Found ""$reset"(count $invalid_entries)"$red"" problematic entries with '-' prefix:""$reset"
        for entry in $invalid_entries
            echo "$red""- $entry""$reset"
        end
        
        echo "$blue""Attempting to fix problematic entries...""$reset"
        for entry in $invalid_entries
            set section (echo $entry | cut -d. -f1 | sed 's/^-//')
            echo "$yellow""Fixing: $section by reverting changes""$reset"
            uci revert $section
            echo "$green""Reverted $section""$reset"
        end
        echo "$green""Fix completed for negative entries.""$reset"
        return 0
    else
        echo "$green""No problematic negative entries found.""$reset"
        return 1
    end
end

# Function to fix missing network interfaces referenced in firewall
function fix_firewall_references
    echo "$purple""Checking for missing network interfaces referenced in firewall zones...""$reset"
    
    set defined_interfaces (uci show network | grep "=interface" | cut -d. -f2 | cut -d= -f1)
    set issues_found false
    
    for zone in (uci show firewall | grep "\.name=" | cut -d. -f2 | cut -d= -f1)
        set zone_name (uci get firewall.$zone.name 2>/dev/null | tr -d "'")
        set zone_networks (uci get firewall.$zone.network 2>/dev/null | tr -d "'" | tr ' ' ',')
        
        # Check each referenced network
        for net in (echo $zone_networks | tr ',' ' ')
            if not contains $net $defined_interfaces
                echo "$red""ERROR: Network '$net' referenced in firewall zone '$zone_name' does not exist!""$reset"
                set issues_found true
                
                # Prompt to create the missing interface
                echo "$yellow""Would you like to create a fallback network interface for '$net'? [y/N]""$reset"
                read -P '> ' create_response
                
                if test "$create_response" = "y" -o "$create_response" = "Y"
                    echo "$blue""Creating fallback network interface '$net'...""$reset"
                    uci set "network.$net"='interface'
                    uci set "network.$net.proto"='static'
                    uci set "network.$net.device"='br-lan'
                    
                    # Set a default IP based on common naming patterns
                    switch $net
                        case "core"
                            uci set "network.$net.ipaddr"='10.0.0.1'
                            uci set "network.$net.netmask"='255.255.255.0'
                        case "guest"
                            uci set "network.$net.ipaddr"='192.168.90.1'
                            uci set "network.$net.netmask"='255.255.255.0'
                        case "iot"
                            uci set "network.$net.ipaddr"='10.0.80.1'
                            uci set "network.$net.netmask"='255.255.255.0'
                        case "meta"
                            uci set "network.$net.ipaddr"='10.0.70.1'
                            uci set "network.$net.netmask"='255.255.255.0'
                        case "nodes"
                            uci set "network.$net.ipaddr"='10.0.20.1'
                            uci set "network.$net.netmask"='255.255.255.0'
                        case "nexus"
                            uci set "network.$net.ipaddr"='10.0.10.1'
                            uci set "network.$net.netmask"='255.255.255.0'
                        case '*'
                            uci set "network.$net.ipaddr"='192.168.100.1'
                            uci set "network.$net.netmask"='255.255.255.0'
                    end
                    
                    echo "$green""Created fallback network '$net'""$reset"
                end
            end
        end
    end
    
    if test "$issues_found" = "true"
        echo "$green""Fixed firewall network references.""$reset"
        return 0
    else
        echo "$green""No firewall reference issues found.""$reset"
        return 1
    end
}

# Function to fix wireless network references
function fix_wireless_references
    echo "$purple""Checking for missing network interfaces referenced in wireless configurations...""$reset"
    
    set defined_interfaces (uci show network | grep "=interface" | cut -d. -f2 | cut -d= -f1)
    set issues_found false
    
    for iface in (uci show wireless | grep "=wifi-iface" | cut -d. -f2 | cut -d= -f1)
        set network (uci get wireless.$iface.network 2>/dev/null | tr -d "'")
        set ssid (uci get wireless.$iface.ssid 2>/dev/null | tr -d "'")
        
        # Check if network exists
        if test -n "$network"; and not contains "$network" $defined_interfaces
            echo "$red""ERROR: Network '$network' referenced by SSID '$ssid' does not exist!""$reset"
            set issues_found true
            
            # Prompt to fix
            echo "$yellow""Would you like to create a fallback network interface for '$network'? [y/N]""$reset"
            read -P '> ' create_response
            
            if test "$create_response" = "y" -o "$create_response" = "Y"
                echo "$blue""Creating fallback network interface '$network'...""$reset"
                uci set "network.$network"='interface'
                uci set "network.$network.proto"='static'
                uci set "network.$network.device"='br-lan'
                
                # Set a default IP based on common naming patterns
                switch $network
                    case "core"
                        uci set "network.$network.ipaddr"='10.0.0.1'
                        uci set "network.$network.netmask"='255.255.255.0'
                    case "guest"
                        uci set "network.$network.ipaddr"='192.168.90.1'
                        uci set "network.$network.netmask"='255.255.255.0'
                    case "iot"
                        uci set "network.$network.ipaddr"='10.0.80.1'
                        uci set "network.$network.netmask"='255.255.255.0'
                    case "meta"
                        uci set "network.$network.ipaddr"='10.0.70.1'
                        uci set "network.$network.netmask"='255.255.255.0'
                    case "*"
                        uci set "network.$network.ipaddr"='192.168.100.1'
                        uci set "network.$network.netmask"='255.255.255.0'
                end
                
                echo "$green""Created fallback network '$network'""$reset"
            end
        end
    end
    
    if test "$issues_found" = "true"
        echo "$green""Fixed wireless network references.""$reset"
        return 0
    else
        echo "$green""No wireless reference issues found.""$reset"
        return 1
    end
}

echo "$yellow""This tool will check your configuration for common issues and offer to fix them.""$reset"
echo "$yellow""Would you like to proceed? [Y/n]""$reset"
read -P '> ' proceed_response

if test "$proceed_response" = "n" -o "$proceed_response" = "N"
    echo "$blue""Operation canceled.""$reset"
    exit 0
end

# Check for issues
echo "$purple""Starting configuration check...""$reset"

# Track if we made any changes
set changes_made false

# Fix negative entries
if fix_negative_entries
    set changes_made true
end

# Fix firewall references
if fix_firewall_references
    set changes_made true
end

# Fix wireless references
if fix_wireless_references
    set changes_made true
end

# If changes were made, ask to commit
if test "$changes_made" = "true"
    echo "$yellow""Configuration fixes have been applied but not committed.""$reset"
    echo "$yellow""Would you like to commit these changes now? [Y/n]""$reset"
    read -P '> ' commit_response
    
    if not test "$commit_response" = "n" -o "$commit_response" = "N"
        echo "$blue""Committing changes...""$reset"
        uci commit
        echo "$green""Changes committed successfully.""$reset"
    else
        echo "$blue""Changes pending but not committed. Use 'uci commit' to apply.""$reset"
    end
else
    echo "$green""No issues found or fixed in configuration.""$reset"
end

echo "$purple""Configuration check completed.""$reset"
exit 0
