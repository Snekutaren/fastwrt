#!/usr/bin/fish
# FastWrt settings configuration script - Implementation using fish shell
# Fish shell is the default shell in FastWrt and should be used for all scripts

# Source common color definitions
source "$PROFILE_DIR/colors.fish"

# Ensure the script runs from its own directory
cd $BASE_DIR
print_info "Current working directory: "(pwd)

# Log the purpose of the script
print_start "Starting settings configuration script to apply system-wide settings..."

### --- System Settings ---
# Using individual UCI commands instead of batch for fish compatibility
echo "$blue""Configuring system settings...""$reset"

# First verify if system section exists and create if needed
if not uci -q get system.@system[0] > /dev/null
    echo "$yellow""Creating system section as it doesn't exist...""$reset"
    uci add system system
end

# Now set the values with proper UCI syntax
echo "$blue""Setting hostname to FastWrt...""$reset"
uci set system.@system[0]='system'
uci set system.@system[0].hostname='FastWrt'
echo "$blue""Setting timezone to CET-1CEST,M3.5.0,M10.5.0/3...""$reset"
uci set system.@system[0].timezone='CET-1CEST,M3.5.0,M10.5.0/3'
echo "$blue""Setting zonename to Europe/Stockholm...""$reset"
uci set system.@system[0].zonename='Europe/Stockholm'

# Set fish as the default shell
echo "$blue""Setting fish as the default shell...""$reset"
if grep -q "/bin/ash" /etc/passwd
    echo "$yellow""Changing default shell from ash to fish...""$reset"
    sed -i 's|/bin/ash$|/usr/bin/fish|' /etc/passwd
    echo "$green""Default shell changed to fish""$reset"
else
    echo "$yellow""Default shell doesn't appear to be /bin/ash, skipping modification""$reset"
end  # Changed from 'fi' to 'end' for consistent fish shell syntax

# Make sure fish is installed - CRITICAL REQUIREMENT
echo "$blue""Verifying fish shell installation...""$reset"
if not command -v fish > /dev/null 2>&1
    echo "$red""ERROR: Fish shell is not installed!""$reset"
    echo "$red""Fish shell is REQUIRED for FastWrt scripts to function properly.""$reset"
    echo "$red""Please install fish shell first using: opkg update && opkg install fish""$reset"
    exit 1
else
    echo "$green""Fish shell is properly installed""$reset"
end

# Create a symbolic link to ensure fish is available in PATH
if test -f /usr/bin/fish; and not test -f /bin/fish
    echo "$blue""Creating symbolic link for fish in /bin...""$reset"
    ln -sf /usr/bin/fish /bin/fish
    echo "$green""Symbolic link created""$reset"
end

# Verify fish shell is actually running - CRITICAL CHECK
echo "$blue""Verifying fish shell execution...""$reset"
if test (basename (status -f)) = "20-settings.sh"
    echo "$green""Confirmed: This script is running under fish shell""$reset"
else
    echo "$red""CRITICAL ERROR: This script is NOT running under fish shell!""$reset"
    echo "$red""FastWrt requires all scripts to be executed with fish shell interpreter.""$reset"
    echo "$red""Please run this script with: fish 20-settings.sh""$reset"
    # No attempt to continue - we abort immediately
    exit 1
end

# Verify the shell for future logins
echo "$yellow""Default shell for future logins: ""$reset"(grep "^root:" /etc/passwd | cut -d: -f7)

# Verify the changes were applied
echo "$yellow""Verifying system settings...""$reset"
echo "Hostname: "(uci get system.@system[0].hostname)
echo "Timezone: "(uci get system.@system[0].timezone)
echo "Zonename: "(uci get system.@system[0].zonename)
echo "Default shell: "(grep "^root:" /etc/passwd | cut -d: -f7)

# Apply timezone settings immediately
echo "$blue""Applying timezone settings immediately...""$reset"
if test -f /etc/init.d/system
    echo "$green""Reloading system services to apply timezone...""$reset"
    /etc/init.d/system reload
else
    echo "$yellow""No system init.d script found, applying timezone settings manually...""$reset"
    
    # Apply timezone settings using standard tools
    ln -sf /usr/share/zoneinfo/Europe/Stockholm /tmp/localtime
    ln -sf /tmp/localtime /etc/localtime
    
    # Update system time from hardware clock if available
    if test -f /sbin/hwclock
        hwclock -s
    end
end

# Router password configuration - added from separate file
echo "$blue""Configuring router password...""$reset"

# Check for router password file in multiple locations using profile hierarchy
set ROUTER_PASSWORD_FILES "$PROFILE_DIR/passwd.fish" "$DEFAULTS_DIR/passwd.fish" "$CONFIG_DIR/passwd.fish" "$BASE_DIR/passwd.fish"
set ROUTER_PASSWORD_FILE ""

for file_path in $ROUTER_PASSWORD_FILES
    if test -f "$file_path"
        echo "$green""Loading router password from: $file_path""$reset"
        source "$file_path"
        set ROUTER_PASSWORD_FILE "$file_path"
        break
    end
end

if test -z "$ROUTER_PASSWORD_FILE"
    echo "$yellow""Router password file not found, using settings configuration""$reset"
end

# Generate random password if not set
if not set -q ROUTER_PASSWORD
    # First check if openssl is available
    if command -v openssl >/dev/null 2>&1
        # Generate a secure random password with openssl
        set -gx ROUTER_PASSWORD (openssl rand -base64 12)
        echo "$green""Generated random router password using OpenSSL""$reset"
    else
        # Fallback to built-in random password generation when openssl is not available
        # This uses fish's built-in random function
        set -gx ROUTER_PASSWORD (string join "" (for i in (seq 16); echo (string sub -s (random 1 63) "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"); end))
        echo "$yellow""OpenSSL not found, using fallback random password generator""$reset"
        echo "$green""Generated random router password using fallback method""$reset"
    end
    
    if test "$DEBUG" = "true"
        echo "$yellow""Password: $ROUTER_PASSWORD""$reset"
    else
        echo "$yellow""Password generated (use --debug to display)""$reset"
    end
end

# Apply the password to the system
echo "$blue""Setting system password...""$reset"
echo -e "$ROUTER_PASSWORD\n$ROUTER_PASSWORD" | passwd root > /dev/null 2>&1

if test $status -eq 0
    echo "$green""System password set successfully""$reset"
else
    echo "$red""Failed to set system password""$reset"
end

# Configure cron jobs from cron.fish file
echo "$blue""Configuring scheduled tasks (cron jobs)...""$reset"

# Check for cron configuration file in multiple locations using profile hierarchy
set CRON_FILES "$PROFILE_DIR/cron.fish" "$DEFAULTS_DIR/cron.fish" "$CONFIG_DIR/cron.fish" "$BASE_DIR/cron.fish"
set CRON_FILE ""

for file_path in $CRON_FILES
    if test -f "$file_path"
        echo "$green""Loading cron configuration from: $file_path""$reset"
        source "$file_path"
        set CRON_FILE "$file_path"
        break
    end
end

if test -z "$CRON_FILE"
    echo "$yellow""Cron configuration file not found, using default settings""$reset"
else
    echo "$green""Cron configuration loaded from $CRON_FILE""$reset"
    
    # Apply cron entries to system crontab if CRON_ENTRIES is defined
    if set -q CRON_ENTRIES; and test (count $CRON_ENTRIES) -gt 0
        echo "$blue""Applying "(count $CRON_ENTRIES)" cron entries...""$reset"
        
        # Ensure crontab directory exists
        mkdir -p /etc/crontabs
        
        # Process each cron entry
        for entry in $CRON_ENTRIES
            # Check if entry already exists in crontab
            if not grep -q "$entry" /etc/crontabs/root 2>/dev/null
                echo "$entry" >> /etc/crontabs/root
                echo "$green""Added cron entry: $entry""$reset"
            else
                echo "$yellow""Cron entry already exists: $entry""$reset"
            end
        end
        
        # Ensure cron service is enabled
        /etc/init.d/cron enable
        /etc/init.d/cron restart
    end
end

echo "$green""System settings configuration completed.""$reset"
# Note: UCI commits are handled in 99-commit.sh