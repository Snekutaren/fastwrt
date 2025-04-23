#!/usr/bin/fish
# FastWrt SSH security hardening script - Primary script for SSH security
# This script provides comprehensive SSH security configuration and should be run 
# after the initial setup or whenever SSH security settings need to be updated.

# Ensure the script runs from its own directory
cd $BASE_DIR
echo "Current working directory: "(pwd)

# Log the purpose of the script
echo "Starting comprehensive SSH security hardening script..."

### --- SSH Security Configuration ---

# Function to add an authorized key if it doesn't exist
function add_authorized_key
    set key_file $argv[1]
    set authorized_keys_file "/etc/dropbear/authorized_keys"
    
    # Create directory if it doesn't exist
    mkdir -p (dirname $authorized_keys_file)
    
    # Check if key file exists
    if test -f "$key_file"
        echo "Adding SSH key from $key_file to authorized_keys"
        
        # Check if authorized_keys exists, create if not
        if not test -f "$authorized_keys_file"
            touch "$authorized_keys_file"
            chmod 600 "$authorized_keys_file"
        end
        
        # Add the key if it's not already in the file
        if not grep -q (cat $key_file | cut -d' ' -f2) "$authorized_keys_file"
            cat "$key_file" >> "$authorized_keys_file"
            echo "✓ SSH key added successfully"
        else
            echo "✓ SSH key already exists in authorized_keys"
        end
    else
        echo "WARNING: SSH key file $key_file not found!"
    end
end

### --- Enable Fail2Ban ---
echo "Setting up Fail2Ban for SSH protection..."

# Check if fail2ban is installed
if command -v fail2ban-client > /dev/null 2>&1
    echo "Configuring fail2ban for SSH..."
    
    # Create fail2ban jail for dropbear
    set fail2ban_config "/etc/fail2ban/jail.d/dropbear.conf"
    
    # Create directory if it doesn't exist
    mkdir -p (dirname $fail2ban_config)
    
    # Create configuration file with improved settings
    echo "[dropbear]
enabled = true
port = 6622
filter = dropbear
logpath = /var/log/messages
maxretry = 3
bantime = 7200
findtime = 600" > $fail2ban_config
    
    # Ensure fail2ban is enabled and started
    /etc/init.d/fail2ban enable
    /etc/init.d/fail2ban restart
    
    echo "✓ Fail2ban configured for SSH protection with stricter settings"
else
    echo "WARNING: fail2ban is not installed. Installing..."
    
    # Try to install fail2ban
    opkg update
    opkg install fail2ban
    
    # Check if installation was successful
    if command -v fail2ban-client > /dev/null 2>&1
        echo "Configuring fail2ban for SSH..."
        
        # Create fail2ban jail for dropbear
        set fail2ban_config "/etc/fail2ban/jail.d/dropbear.conf"
        
        # Create directory if it doesn't exist
        mkdir -p (dirname $fail2ban_config)
        
        # Create configuration file with improved settings
        echo "[dropbear]
enabled = true
port = 6622
filter = dropbear
logpath = /var/log/messages
maxretry = 3
bantime = 7200
findtime = 600" > $fail2ban_config
        
        # Ensure fail2ban is enabled and started
        /etc/init.d/fail2ban enable
        /etc/init.d/fail2ban restart
        
        echo "✓ Fail2ban installed and configured for SSH protection"
    else
        echo "ERROR: Failed to install fail2ban. Manual installation required."
        echo "Run: opkg update && opkg install fail2ban"
    end
end

### --- Advanced Firewall Rules for SSH ---
echo "Adding advanced firewall rules for SSH protection..."

# Add rule to limit SSH connection attempts with more granular control
uci set firewall.ssh_limit='rule'
uci set firewall.ssh_limit.name="SSH-Limit"
uci set firewall.ssh_limit.src="wan"
uci set firewall.ssh_limit.proto="tcp"
uci set firewall.ssh_limit.dest_port="6622"
uci set firewall.ssh_limit.limit="10/minute"
uci set firewall.ssh_limit.target="ACCEPT"

# Enhanced SSH protection rule - Add connection tracking
uci set firewall.ssh_protect='rule'
uci set firewall.ssh_protect.name="SSH-Protection"
uci set firewall.ssh_protect.src="wan"
uci set firewall.ssh_protect.proto="tcp"
uci set firewall.ssh_protect.dest_port="6622"
uci set firewall.ssh_protect.target="DROP"
uci set firewall.ssh_protect.limit="1/second"
uci set firewall.ssh_protect.connbytes="60"
uci set firewall.ssh_protect.connbytes_mode="connbytes"
uci set firewall.ssh_protect.connbytes_dir="original"

echo "Advanced SSH protection rules configured"

### --- Set SSH Key Path and Disable Password Authentication ---
echo "Checking for SSH authorized keys..."

# Look for SSH keys in all available locations
set key_paths "$BASE_DIR/ssh_keys/*.pub" "$BASE_DIR/ssh_keys/authorized_keys" "/tmp/authorized_keys"

# Check for standard key files specifically
if test -f "$BASE_DIR/ssh_keys/id_ed25519.pub"
    echo "Found id_ed25519.pub key"
    add_authorized_key "$BASE_DIR/ssh_keys/id_ed25519.pub"
end

if test -f "$BASE_DIR/ssh_keys/id_rsa.pub"
    echo "Found id_rsa.pub key"
    add_authorized_key "$BASE_DIR/ssh_keys/id_rsa.pub"
end

# Add any other available keys from key_paths
for key_path in $key_paths
    for key_file in $key_path
        if test -f "$key_file"
            add_authorized_key "$key_file"
        end
    end
end

# Enhanced SSH configuration for Dropbear
echo "Configuring advanced SSH security settings..."
uci set dropbear.@dropbear[0].Interface='core'  # Restrict to core interface
uci set dropbear.@dropbear[0].Port='6622'       # Non-standard port
uci set dropbear.@dropbear[0].IdleTimeout='300'  # 5 minute idle timeout
uci set dropbear.@dropbear[0].MaxAuthTries='3'   # Limit authentication attempts

# Disable password authentication only if we have at least one key
if test -f "/etc/dropbear/authorized_keys"
    if not grep -q "ssh-" "/etc/dropbear/authorized_keys"
        echo "WARNING: No valid SSH keys found in authorized_keys file. Password authentication will remain enabled."
        echo "For security reasons, it's STRONGLY recommended to add an SSH key before disabling password auth."
    else
        echo "Valid SSH keys found. Disabling password authentication..."
        uci set dropbear.@dropbear[0].PasswordAuth='off'
        uci set dropbear.@dropbear[0].RootPasswordAuth='off'
    end
else
    echo "WARNING: No authorized_keys file found. Password authentication will remain enabled."
    echo "To disable password authentication, add an SSH key and run this script again."
end

# Create additional scripts for enhanced security

# Create a script to generate a weekly security report
echo "Creating SSH security monitoring script..."
echo '#!/usr/bin/fish
# SSH security report script
echo "Generating SSH security report..."

# Date and report file
set DATE (date +"%Y-%m-%d")
set REPORT_FILE "/root/ssh_security_report_$DATE.log"

# Check for failed logins
echo "SSH Failed Login Attempts:" > $REPORT_FILE
grep "Failed password" /var/log/messages | tail -50 >> $REPORT_FILE
echo "" >> $REPORT_FILE

# Check for successful logins
echo "SSH Successful Logins:" >> $REPORT_FILE
grep "Accepted password\|Accepted publickey" /var/log/messages | tail -20 >> $REPORT_FILE
echo "" >> $REPORT_FILE

# Check for banned IPs if fail2ban is installed
if command -v fail2ban-client > /dev/null 2>&1
    echo "Fail2Ban Status:" >> $REPORT_FILE
    fail2ban-client status dropbear >> $REPORT_FILE
    echo "" >> $REPORT_FILE
end

echo "Security report generated at $REPORT_FILE"
' > "$BASE_DIR/helpers/ssh_security_report.sh"
chmod +x "$BASE_DIR/helpers/ssh_security_report.sh"

# Log additional security recommendations
echo "
SSH Security Recommendations:
----------------------------
1. Consider changing the SSH port regularly
2. Monitor /var/log/messages for unauthorized access attempts
3. Run the ssh_security_report.sh script weekly
4. Add additional SSH keys for other authorized administrators
5. Set up automatic security updates
6. Consider implementing port knocking for additional security
"

# Note: UCI commits are handled in 98-commit.sh
echo "SSH security hardening completed. Changes will be applied during final commit."

echo "SSH security configuration completed successfully."