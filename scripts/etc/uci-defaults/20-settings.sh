#!/usr/bin/fish
# FastWrt settings configuration script - Pure fish implementation

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

# Verify the changes were applied
echo "$yellow""Verifying system settings...""$reset"
echo "Hostname: "(uci get system.@system[0].hostname)
echo "Timezone: "(uci get system.@system[0].timezone)
echo "Zonename: "(uci get system.@system[0].zonename)

echo "$green""System settings configuration completed.""$reset"
# Note: UCI commits are handled in 99-commit.sh