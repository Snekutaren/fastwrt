#!/usr/bin/fish
# FastWrt settings configuration script - Pure fish implementation

# Ensure the script runs from its own directory
cd $BASE_DIR
echo "Current working directory: "(pwd)

# Log the purpose of the script
echo "Starting settings configuration script to apply system-wide settings..."

### --- System Settings ---
# Using individual UCI commands instead of batch for fish compatibility
echo "Configuring system settings..."

# First verify if system section exists and create if needed
if not uci -q get system.@system[0] > /dev/null
    echo "Creating system section as it doesn't exist..."
    uci add system system
end

# Now set the values with proper UCI syntax
echo "Setting hostname to FastWrt..."
uci set system.@system[0]='system'
uci set system.@system[0].hostname='FastWrt'
echo "Setting timezone to CET-1CEST,M3.5.0,M10.5.0/3..."
uci set system.@system[0].timezone='CET-1CEST,M3.5.0,M10.5.0/3'
echo "Setting zonename to Europe/Stockholm..."
uci set system.@system[0].zonename='Europe/Stockholm'

# Verify the changes were applied
echo "Verifying system settings..."
echo "Hostname: "(uci get system.@system[0].hostname)
echo "Timezone: "(uci get system.@system[0].timezone)
echo "Zonename: "(uci get system.@system[0].zonename)

echo "System settings configuration completed."
# Note: UCI commits are handled in 99-commit.sh