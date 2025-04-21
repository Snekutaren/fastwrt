#!/usr/bin/fish
# FastWrt Dropbear (SSH) configuration - Pure fish implementation

# Ensure the script runs from its own directory
cd $BASE_DIR
echo "Current working directory: "(pwd)

# Log the purpose of the script
echo "Starting Dropbear configuration script to set up SSH access..."

### --- Dropbear (SSH) ---
echo "Setting Dropbear interface to 'core'..."
uci set dropbear.@dropbear[0].Interface='core'
echo "Setting Dropbear port to '6622'..."
uci set dropbear.@dropbear[0].Port='6622'
echo "Enabling Dropbear password authentication (NOTE: Disable later!)..."
uci set dropbear.@dropbear[0].PasswordAuth='on'  # NOTE: Disable later!
echo "Enabling Dropbear root password authentication..."
uci set dropbear.@dropbear[0].RootPasswordAuth='on'

# Restart dropbear to apply changes
echo "Restarting Dropbear service to apply changes..."
/etc/init.d/dropbear restart

# Verify port is properly set
echo "Verifying Dropbear configuration..."
uci get dropbear.@dropbear[0].Port

# Commit changes
uci commit dropbear
echo "Dropbear configuration completed successfully."