#!/bin/sh
set -e  # Exit on any error
# Ensure the script runs from its own directory
cd "$BASE_DIR"
echo "Current working directory: $(pwd)"

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