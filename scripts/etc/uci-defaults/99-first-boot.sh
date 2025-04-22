#!/usr/bin/fish

# filepath: /etc/uci-defaults/99-first-boot.fish

set LOGFILE "/tmp/first-boot.log"
echo "Starting FastWrt first boot configuration at (date)" > $LOGFILE

# Create required directories
mkdir -p /etc/dropbear
chmod 700 /etc/dropbear

function add_default_ssh_key
    echo "Setting up initial SSH key for secure access..." >> $LOGFILE

    touch /etc/dropbear/authorized_keys
    chmod 600 /etc/dropbear/authorized_keys

    if test -f "/etc/FastWrt/ssh_keys/id_ed25519.pub"
        cat "/etc/FastWrt/ssh_keys/id_ed25519.pub" >> /etc/dropbear/authorized_keys
        echo "SSH key added successfully from installed id_ed25519.pub" >> $LOGFILE
    else
        echo "No SSH key found in standard location, using embedded key..." >> $LOGFILE
        begin
            echo "ssh-rsa AAAA...YOUR_SSH_PUBLIC_KEY_HERE...== user@example.com"
        end >> /etc/dropbear/authorized_keys
    end

    chmod 600 /etc/dropbear/authorized_keys
end

function configure_initial_ssh
    echo "Configuring initial secure SSH settings..." >> $LOGFILE

    uci set dropbear.@dropbear[0].Interface='core'
    uci set dropbear.@dropbear[0].Port='6622'

    if grep -q "ssh-" "/etc/dropbear/authorized_keys"
        echo "Valid SSH keys found, disabling password authentication" >> $LOGFILE
        uci set dropbear.@dropbear[0].PasswordAuth='off'
        uci set dropbear.@dropbear[0].RootPasswordAuth='off'
    else
        echo "No valid SSH keys found, keeping password authentication enabled" >> $LOGFILE
        uci set dropbear.@dropbear[0].PasswordAuth='on'
        uci set dropbear.@dropbear[0].RootPasswordAuth='on'
    end
end

function backup_initial_configs
    echo "Creating initial configuration backups..." >> $LOGFILE
    set BACKUP_DIR "/etc/config/backups"
    mkdir -p $BACKUP_DIR

    for config in network firewall dropbear system dhcp
        cp "/etc/config/$config" "$BACKUP_DIR/$config.initial"
    end

    echo "Initial configuration backups created" >> $LOGFILE
end

# Execute functions
echo "Executing first boot tasks..." >> $LOGFILE
add_default_ssh_key
configure_initial_ssh
backup_initial_configs

# Write reminder banner
begin
    echo "======================================================="
    echo "FastWrt initial setup complete!"
    echo ""
    echo "SECURITY NOTICE:"
    echo "- SSH is accessible ONLY from internal networks and WireGuard"
    echo "- For remote access, connect to WireGuard VPN first"
    echo ""
    echo "For full security hardening, run:"
    echo "  cd /etc/FastWrt/Firmware && ./scripts/secure_ssh.sh"
    echo "======================================================="
end > /etc/banner.post-sysupgrade

echo "First boot configuration completed at (date)" >> $LOGFILE
echo "FastWrt first boot configuration completed successfully. See $LOGFILE for details." > /dev/console

exit 0
