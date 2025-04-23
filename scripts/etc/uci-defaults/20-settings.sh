#!/usr/bin/fish
# FastWrt settings configuration script - Implementation using fish shell
# Fish shell is the default shell in FastWrt and should be used for all scripts

# Set colors for better readability
set green (echo -e "\033[0;32m")
set yellow (echo -e "\033[0;33m")
set red (echo -e "\033[0;31m")
set blue (echo -e "\033[0;34m")
set purple (echo -e "\033[0;35m")
set reset (echo -e "\033[0m")

# Ensure the script runs from its own directory
cd $BASE_DIR
echo "$blue""Current working directory: ""$reset"(pwd)

# Log the purpose of the script
echo "$purple""Starting settings configuration script to apply system-wide settings...""$reset"

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

echo "$green""System settings configuration completed.""$reset"
# Note: UCI commits are handled in 99-commit.sh