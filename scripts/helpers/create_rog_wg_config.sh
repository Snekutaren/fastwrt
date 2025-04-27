#!/usr/bin/fish
# Helper script to generate WireGuard config for the ROG client

# Source colors from profile directory or use defaults
set COLORS_FILES "$PROFILE_DIR/colors.fish" "$DEFAULTS_DIR/colors.fish" "$CONFIG_DIR/colors.fish" "$BASE_DIR/colors.fish" "$BASE_DIR/scripts/etc/uci-defaults/config/profiles/sne/colors.fish"
for file_path in $COLORS_FILES
    if test -f "$file_path"
        source "$file_path"
        break
    end
end

# Fallback if colors not loaded
if not set -q green
    set green (echo -e "\033[0;32m")
    set yellow (echo -e "\033[0;33m")
    set red (echo -e "\033[0;31m")
    set blue (echo -e "\033[0;34m")
    set purple (echo -e "\033[0;35m")
    set reset (echo -e "\033[0m")
end

# Check for the existence of the server's public key
set SERVER_PUBLIC_KEY_FILE "/etc/wireguard/server_public.key"
set ROG_PRIVATE_KEY_FILE "/etc/wireguard/rog_private.key"

echo "$purple""ROG WireGuard Client Configuration Generator""$reset"
echo "$blue""This script will generate a client configuration for the ROG device.""$reset"

# Prompt for the server's endpoint (public IP or hostname)
echo "$yellow""Please enter the server's public IP or hostname:""$reset"
read SERVER_ENDPOINT

# Check if we need to append the port
if not string match -q "*:*" -- "$SERVER_ENDPOINT"
    set SERVER_ENDPOINT "$SERVER_ENDPOINT:52018"
end

# Check if we have the server's public key
if not test -f "$SERVER_PUBLIC_KEY_FILE"
    echo "$red""Server public key not found at $SERVER_PUBLIC_KEY_FILE""$reset"
    echo "$yellow""Would you like to enter the server's public key manually? (y/n)""$reset"
    read MANUAL_KEY
    
    if string match -q "y*" -- "$MANUAL_KEY"
        echo "$yellow""Enter the server's public key:""$reset"
        read SERVER_PUBLIC_KEY
    else
        echo "$red""Cannot continue without server public key.""$reset"
        exit 1
    end
else
    set SERVER_PUBLIC_KEY (cat "$SERVER_PUBLIC_KEY_FILE")
    echo "$green""Found server public key: $SERVER_PUBLIC_KEY""$reset"
end

# Check if we have the ROG private key or need to generate it
if not test -f "$ROG_PRIVATE_KEY_FILE"
    echo "$yellow""ROG private key not found. Generating new keypair...""$reset"
    mkdir -p (dirname "$ROG_PRIVATE_KEY_FILE")
    wg genkey | tee "$ROG_PRIVATE_KEY_FILE" | wg pubkey > "/etc/wireguard/rog_public.key"
    chmod 600 "$ROG_PRIVATE_KEY_FILE" "/etc/wireguard/rog_public.key"
    echo "$green""New WireGuard keypair generated for ROG""$reset"
    
    echo "$blue""Public key: ""$reset"(cat "/etc/wireguard/rog_public.key")
    echo "$yellow""Remember to update the server configuration with this new public key!""$reset"
    echo "$yellow""Run: uci set network.peer_ROG.public_key='""$reset"(cat "/etc/wireguard/rog_public.key")"$yellow""'""$reset"
    echo "$yellow""Then: uci commit network""$reset"
else
    echo "$green""Using existing ROG private key""$reset"
end

set ROG_PRIVATE_KEY (cat "$ROG_PRIVATE_KEY_FILE")

# Generate the client config
set CONFIG_FILE "/tmp/wg-rog-client.conf"
echo "$blue""Generating WireGuard client configuration file at $CONFIG_FILE""$reset"

# Write the configuration file
echo "[Interface]
PrivateKey = $ROG_PRIVATE_KEY
Address = 10.255.0.3/24
DNS = 10.255.0.1

[Peer]
PublicKey = $SERVER_PUBLIC_KEY
AllowedIPs = 0.0.0.0/0
Endpoint = $SERVER_ENDPOINT
PersistentKeepalive = 25" > "$CONFIG_FILE"

echo "$green""WireGuard configuration file for ROG has been generated at $CONFIG_FILE""$reset"
echo "$green""Use this file to configure the WireGuard client on your ROG device.""$reset"
echo "$yellow""You can display the configuration with: cat $CONFIG_FILE""$reset"
echo "$yellow""Or generate a QR code with: qrencode -t ansiutf8 < $CONFIG_FILE""$reset"

# If qrencode is available, offer to display the QR code
if command -v qrencode > /dev/null
    echo "$yellow""Would you like to display a QR code for this configuration? (y/n)""$reset"
    read SHOW_QR
    
    if string match -q "y*" -- "$SHOW_QR"
        echo "$blue""Generating QR code:""$reset"
        qrencode -t ansiutf8 < "$CONFIG_FILE"
    end
else
    echo "$yellow""The 'qrencode' package is not installed. Install it with: opkg update && opkg install qrencode""$reset"
    echo "$yellow""Then you can generate a QR code with: qrencode -t ansiutf8 < $CONFIG_FILE""$reset"
end

echo "$purple""Configuration complete!""$reset"
