# UCI Syntax Reference Guide for FastWrt

This document serves as a comprehensive reference for UCI (Unified Configuration Interface) syntax patterns used throughout the FastWrt project. Following these guidelines will prevent syntax errors and ensure consistent configuration across all script files.

## Table of Contents
1. [Basic UCI Command Structure](#basic-uci-command-structure)
2. [Section Types and Creation](#section-types-and-creation)
3. [Property Assignment](#property-assignment)
4. [List Operations](#list-operations)
5. [Arrays and Anonymous Sections](#arrays-and-anonymous-sections)
6. [Common UCI Configurations by Domain](#common-uci-configurations-by-domain)
7. [UCI Best Practices](#uci-best-practices)
8. [Troubleshooting UCI Syntax Issues](#troubleshooting-uci-syntax-issues)

## Basic UCI Command Structure

### UCI Command Types
```bash
# Get a value
uci get <config>.<section>.<option>

# Set a value
uci set <config>.<section>.<option>='<value>'

# Add a new section
uci add <config> <sectiontype>

# Delete a section or option
uci delete <config>.<section>[.<option>]

# Add list item
uci add_list <config>.<section>.<option>='<value>'

# Delete list item
uci del_list <config>.<section>.<option>='<value>'

# Commit changes
uci commit [<config>]
```

## Section Types and Creation

### Named Sections
When creating named sections, always use single quotes around the section type:

```bash
# CORRECT - Use single quotes for section types
uci set network.lan='interface'
uci set firewall.wan='zone'
uci set wireless.radio0='wifi-device'
uci set wireless.wifinet0='wifi-iface'
uci set dhcp.wan='dhcp'
uci set system.@system[0]='system'

# INCORRECT - Missing quotes for section types (will cause errors)
uci set network.lan=interface
uci set firewall.wan=zone
```

### Anonymous Sections
When creating anonymous sections, always set the section type immediately after creation:

```bash
# CORRECT - Create section and immediately set its type
uci add firewall rule
uci set firewall.@rule[-1]='rule'

# CORRECT - For zones
uci add firewall zone
uci set firewall.@zone[-1]='zone'

# CORRECT - For redirects
uci add firewall redirect
uci set firewall.@redirect[-1]='redirect'

# CORRECT - For forwarding
uci add firewall forwarding
uci set firewall.@forwarding[-1]='forwarding'

# INCORRECT - No section type specified after creation
uci add firewall rule
# Missing section type definition!
```

## Property Assignment

### Simple Values
Always use single quotes around simple string values and ensure there's no space before the equals sign:

```bash
# CORRECT - Single quotes for string values, no space before equals
uci set network.lan.ipaddr='192.168.1.1'
uci set system.@system[0].hostname='FastWrt'
uci set firewall.@defaults[0].input='DROP'

# INCORRECT - Space before equals sign
uci set network.lan.ipaddr ='192.168.1.1'

# INCORRECT - No quotes around values
uci set network.lan.ipaddr=192.168.1.1
```

### Variable Values
When assigning variable values, use double quotes and ensure there's no space before the equals sign:

```bash
# CORRECT - Double quotes for variable values, no space before equals
uci set network.wireguard.ipaddr="$WIREGUARD_IP"
uci set firewall.core.input="$CORE_POLICY_IN"

# INCORRECT - Space before equals sign
uci set firewall.core.input ="$CORE_POLICY_IN"

# INCORRECT - No quotes or single quotes around variables
uci set network.wireguard.ipaddr=$WIREGUARD_IP
uci set firewall.core.input='$CORE_POLICY_IN'  # Variable won't be expanded
```

### Boolean and Numeric Values
Use single quotes for consistency, even with boolean (0/1) and numeric values:

```bash
# CORRECT - Single quotes for booleans and numbers
uci set wireless.radio0.disabled='0'
uci set firewall.@defaults[0].syn_flood='1'
uci set dhcp.@dnsmasq[-1].cachesize='1000'

# ACCEPTABLE but less consistent with other values
uci set wireless.radio0.disabled=0
```

## List Operations

### Adding List Items
When adding items to lists, use single quotes for fixed values and double quotes for variables:

```bash
# CORRECT - Adding fixed values to lists with single quotes
uci add_list dhcp.@dnsmasq[-1].server='1.1.1.1'
uci add_list network.lan_dev.ports='lan1'

# CORRECT - Adding variable values with double quotes
uci add_list network.lan_dev.ports "$port"

# INCORRECT - No quotes around values
uci add_list dhcp.@dnsmasq[-1].server=1.1.1.1
```

### Clearing Lists
Before repopulating lists, properly clear them to avoid duplicates:

```bash
# CORRECT - Clear list before adding new items
uci delete network.lan_dev.ports
uci add_list network.lan_dev.ports='lan1'
uci add_list network.lan_dev.ports='lan2'

# INCORRECT - Adding to lists without checking for duplicates
uci add_list network.lan_dev.ports='lan1'  # May cause duplicate entries
```

## Arrays and Anonymous Sections

### Working with Arrays
When referencing array elements, use the correct index notation:

```bash
# CORRECT - Reference first item in an array section
uci set system.@system[0].hostname='FastWrt'

# CORRECT - Reference newest/last added anonymous section
uci set firewall.@rule[-1].name='Allow-DHCP'

# INCORRECT - Malformed array index 
uci set system.@system.hostname='FastWrt'  # Missing index
```

### Copying Properties Between Sections
When copying properties between sections, maintain proper quoting:

```bash
# CORRECT - Copying properties between sections
for prop in (uci show firewall.$rule | cut -d= -f1)
  set prop_name (echo "$prop" | cut -d. -f3)
  set prop_value (uci get $prop 2>/dev/null)
  uci set firewall.@rule[-1].$prop_name "$prop_value"
end
```

## Common UCI Configurations by Domain

### Network Configuration
```bash
# Interface definition
uci set network.lan='interface'
uci set network.lan.device='br-lan'
uci set network.lan.proto='static'
uci set network.lan.ipaddr='192.168.1.1'
uci set network.lan.netmask='255.255.255.0'

# Bridge device
uci set network.br_lan='device'
uci set network.br_lan.name='br-lan'
uci set network.br_lan.type='bridge'
uci add_list network.br_lan.ports='eth0'
uci add_list network.br_lan.ports='eth1'

# VLAN
uci set network.vlan10='bridge-vlan'
uci set network.vlan10.device='br-lan'
uci set network.vlan10.vlan='10'
```

### Firewall Configuration
```bash
# Zone definition
uci set firewall.wan='zone'
uci set firewall.wan.name='wan'
uci set firewall.wan.network='wan'
uci set firewall.wan.input='DROP'
uci set firewall.wan.output='ACCEPT'
uci set firewall.wan.forward='DROP'

# Rule definition
uci add firewall rule
uci set firewall.@rule[-1]='rule'
uci set firewall.@rule[-1].name='Allow-DHCP'
uci set firewall.@rule[-1].src='wan'
uci set firewall.@rule[-1].proto='udp'
uci set firewall.@rule[-1].dest_port='67-68'
uci set firewall.@rule[-1].target='ACCEPT'

# Forwarding definition
uci add firewall forwarding
uci set firewall.@forwarding[-1]='forwarding'
uci set firewall.@forwarding[-1].src='lan'
uci set firewall.@forwarding[-1].dest='wan'
```

### Wireless Configuration
```bash
# Radio device
uci set wireless.radio0='wifi-device'
uci set wireless.radio0.type='mac80211'
uci set wireless.radio0.channel='1'
uci set wireless.radio0.band='2g'
uci set wireless.radio0.htmode='HT20'

# Interface
uci set wireless.default_radio0='wifi-iface'
uci set wireless.default_radio0.device='radio0'
uci set wireless.default_radio0.network='lan'
uci set wireless.default_radio0.mode='ap'
uci set wireless.default_radio0.ssid='OpenWrt'
uci set wireless.default_radio0.encryption='psk2'
uci set wireless.default_radio0.key='password'
```

### DHCP Configuration
```bash
# DHCP server
uci set dhcp.lan='dhcp'
uci set dhcp.lan.interface='lan'
uci set dhcp.lan.start='100'
uci set dhcp.lan.limit='150'
uci set dhcp.lan.leasetime='12h'

# DNS settings
uci add dhcp dnsmasq
uci set dhcp.@dnsmasq[-1]='dnsmasq'
uci set dhcp.@dnsmasq[-1].domainneeded='1'
uci set dhcp.@dnsmasq[-1].boguspriv='1'
uci add_list dhcp.@dnsmasq[-1].server='1.1.1.1'
```

## UCI Best Practices

### 1. Centralized Commits
In the FastWrt architecture, UCI commits are handled centrally by the `01-install.sh` script:
```bash
# CORRECT - Let the main script handle commits
# (Don't add a uci commit in individual configuration scripts)

# INCORRECT - Adding commits in individual scripts
uci commit network  # Don't do this in configuration scripts
```

### 2. Always Verify Changes
Use the verification functionality to check pending changes:
```bash
# Show pending changes for network configuration
uci changes network

# Count total pending changes
uci changes | wc -l
```

### 3. Use Backup Functions Before Changes
Create backups before making major changes:
```bash
# Use the centralized backup functionality
source "$BASE_DIR/helpers/backup_function.sh"
backup_config network

# Or manually create backups
cp /etc/config/network /etc/config/network.bak
```

### 4. Consistent Quoting Style
Maintain consistent use of quotes throughout your code:
- Single quotes for fixed strings
- Double quotes for variables
- Always quote section types

### 5. Organize Related Commands
Group related UCI commands together and add comments to explain their purpose:
```bash
# Configure WAN interface
uci set network.wan='interface'
uci set network.wan.proto='dhcp'
uci set network.wan.device='eth1'
```

## Troubleshooting UCI Syntax Issues

### Common Errors and Solutions

1. **Error**: Failed to set value
   **Solution**: Check for proper quoting around values, especially strings with special characters

2. **Error**: Section not found
   **Solution**: Verify that the section exists before trying to set options on it

3. **Error**: Failed to add section
   **Solution**: Ensure you're using the correct section type and it's properly quoted

4. **Error**: Invalid argument
   **Solution**: Check for proper command syntax and correct number of arguments

### Debugging UCI Commands

Use these techniques to debug UCI issues:

```bash
# Show current configuration
uci show network

# Export configuration in easier-to-read format
uci export network

# Test a command with -q for quiet mode
uci -q get network.lan.ipaddr || echo "Section or option not found"
```

## Color Coding in FastWrt Scripts

FastWrt uses color-coded output for better readability:

```bash
# Standard colors defined in colors.fish
set green (echo -e "\033[0;32m")   # Success messages
set yellow (echo -e "\033[0;33m")  # Warnings and notices
set red (echo -e "\033[0;31m")     # Errors and critical issues
set blue (echo -e "\033[0;34m")    # Information and status updates
set purple (echo -e "\033[0;35m")  # Section headers and major process indicators
set orange (echo -e "\033[0;33m")  # Security-related warnings and advisories
set cyan (echo -e "\033[0;36m")    # Configuration values and technical details
set reset (echo -e "\033[0m")      # Reset color
```

### Standard Color Usage

Each color has a specific purpose in FastWrt scripts:

| Color  | Purpose | Example Usage |
|--------|---------|---------------|
| Green  | Success | "Configuration completed successfully" |
| Yellow | Warning | "Network interface exists, reconfiguring..." |
| Red    | Error   | "Failed to configure interface" |
| Blue   | Info    | "Setting up network interfaces..." |
| Purple | Section | "NETWORK CONFIGURATION" |
| Orange | Security| "Access restricted for security reasons" |
| Cyan   | Values  | "IP address: 192.168.1.1" |

### Using Standard Print Functions

For consistency, use the standard print functions:

```bash
print_error "Failed to configure interface"
print_warning "Configuration already exists, overwriting"
print_security "Found insecure SSH configuration, fixing"
print_success "Configuration completed successfully"
print_info "Setting up network interfaces..."
print_start "NETWORK CONFIGURATION"
print_value "IP address: 192.168.1.1"
```

When using colors, always reset the color after each message to prevent color bleeding into subsequent output.

---

By following these guidelines consistently across all FastWrt scripts, you'll avoid syntax errors and ensure reliable configuration of OpenWrt devices.

Last Updated: April 24, 2025