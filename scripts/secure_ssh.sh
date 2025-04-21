#!/usr/bin/fish
# FastWrt SSH security enhancement script
# This script enhances SSH security by disabling password authentication
# and setting up key-based authentication.

# Ensure the script runs from its own directory
cd $BASE_DIR
echo "Current working directory: "(pwd)

echo "===== SSH Security Enhancement Tool ====="
echo "This script will:
1. Disable password authentication for SSH (more secure)
2. Allow only key-based authentication
3. Create a backup of current SSH configuration"

# Create a backup of the current configuration
echo "Creating backup of current SSH configuration..."
mkdir -p "$BASE_DIR/backups"
cp /etc/config/dropbear "$BASE_DIR/backups/dropbear.backup.(date +%Y%m%d-%H%M%S)"

echo "Do you want to continue? This will require SSH key-based authentication to be set up. (y/n)"
read -l confirmation

if test "$confirmation" != "y"
  echo "Operation cancelled. No changes were made."
  exit 0
end

echo "Checking for authorized_keys file..."
if not test -f "/etc/dropbear/authorized_keys"
  echo "ERROR: No authorized_keys file found. Please set up SSH keys first with:"
  echo "mkdir -p /etc/dropbear"
  echo "echo 'YOUR_PUBLIC_SSH_KEY' > /etc/dropbear/authorized_keys"
  echo "chmod 600 /etc/dropbear/authorized_keys"
  echo "Then run this script again."
  exit 1
end

# Configure SSH security
echo "Disabling password authentication..."
uci set dropbear.@dropbear[0].PasswordAuth='off'

echo "Disabling root password authentication..."
uci set dropbear.@dropbear[0].RootPasswordAuth='off'

# Keep port and interface settings from original configuration
echo "Keeping existing port and interface settings..."
set ssh_port (uci get dropbear.@dropbear[0].Port)
set ssh_interface (uci get dropbear.@dropbear[0].Interface)
echo "Current SSH port: $ssh_port"
echo "Current SSH interface: $ssh_interface"

echo "Do you want to change the SSH port from $ssh_port? (y/n)"
read -l change_port
if test "$change_port" = "y"
  echo "Enter new SSH port:"
  read -l new_port
  # Validate port is numeric
  if string match -qr '^[0-9]+$' "$new_port"
    uci set dropbear.@dropbear[0].Port="$new_port"
    echo "SSH port changed to $new_port"
  else
    echo "Invalid port number. Keeping current port."
  end
end

# Commit changes
echo "Committing changes to dropbear configuration..."
uci commit dropbear

echo "Configuration saved. Do you want to restart SSH service now? (y/n)"
echo "WARNING: If you haven't properly set up SSH keys, you may lose access!"
read -l restart_now

if test "$restart_now" = "y"
  echo "Restarting SSH service..."
  /etc/init.d/dropbear restart
  echo "SSH service restarted with new security settings."
  echo "Password authentication is now disabled."
else
  echo "Changes will take effect on next SSH service restart or router reboot."
end

echo "===== SSH Security Enhancement Complete ====="
echo "Remember: You can only connect using SSH keys now."
echo "If you need to revert these changes, use:"
echo "uci set dropbear.@dropbear[0].PasswordAuth='on'"
echo "uci set dropbear.@dropbear[0].RootPasswordAuth='on'"
echo "uci commit dropbear"