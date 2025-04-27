#!/usr/bin/fish
# FastWrt Secure Passphrase Manager
# This script provides a more secure method to manage Wi-Fi passphrases
# by encrypting them with a master password and storing them in a protected file

# Set colors for better readability
set green (echo -e "\033[0;32m")
set yellow (echo -e "\033[0;33m")
set red (echo -e "\033[0;31m")
set blue (echo -e "\033[0;34m")
set purple (echo -e "\033[0;35m")
set reset (echo -e "\033[0m")

# Default paths
set PASSPHRASE_FILE "/etc/fastwr/passphrases.enc"
set TEMP_ENV_FILE "/tmp/fastwr_env_temp.fish"
set DEFAULT_SALT_FILE "/etc/fastwr/salt.key"

function show_help
    echo "FastWrt Secure Passphrase Manager"
    echo ""
    echo "Usage:"
    echo "  $argv[0] generate [length]     - Generate new random passphrases"
    echo "  $argv[0] encrypt               - Encrypt passphrases"
    echo "  $argv[0] decrypt               - Decrypt passphrases to environment"
    echo "  $argv[0] help                  - Show this help"
    echo ""
    echo "Examples:"
    echo "  $argv[0] generate 32           - Generate 32-character passphrases"
    echo "  $argv[0] encrypt               - Store encrypted passphrases"
    echo "  $argv[0] decrypt               - Load passphrases to environment"
    echo ""
end

function generate_salt
    if test -f "$DEFAULT_SALT_FILE"
        cat "$DEFAULT_SALT_FILE"
    else
        # Generate a random salt for encryption
        set salt (openssl rand -hex 16)
        
        # Ensure directory exists
        mkdir -p (dirname "$DEFAULT_SALT_FILE")
        
        # Store salt securely
        echo "$salt" > "$DEFAULT_SALT_FILE"
        chmod 600 "$DEFAULT_SALT_FILE"
        
        echo "$salt"
    end
end

function generate_passphrases
    set length $argv[1]
    if test -z "$length"
        set length 32
    end
    
    echo "$blue""Generating random passphrases of length $length...""$reset"
    
    # Generate random passphrases for each network
    set PASSPHRASE_OPENWRT (openssl rand -base64 $length | string sub -l $length)
    set PASSPHRASE_CLOSEDWRT (openssl rand -base64 $length | string sub -l $length)
    set PASSPHRASE_IOTWRT (openssl rand -base64 $length | string sub -l $length)
    set PASSPHRASE_METAWRT (openssl rand -base64 $length | string sub -l $length)
    
    # Create temporary environment file
    echo "#!/usr/bin/fish" > "$TEMP_ENV_FILE"
    echo "" >> "$TEMP_ENV_FILE"
    echo "# Generated secure passphrases for WiFi networks" >> "$TEMP_ENV_FILE"
    echo "# Generated on: "(date) >> "$TEMP_ENV_FILE"
    echo "" >> "$TEMP_ENV_FILE"
    echo "set -gx PASSPHRASE_OPENWRT \"$PASSPHRASE_OPENWRT\"" >> "$TEMP_ENV_FILE"
    echo "set -gx PASSPHRASE_CLOSEDWRT \"$PASSPHRASE_CLOSEDWRT\"" >> "$TEMP_ENV_FILE"
    echo "set -gx PASSPHRASE_IOTWRT \"$PASSPHRASE_IOTWRT\"" >> "$TEMP_ENV_FILE"
    echo "set -gx PASSPHRASE_METAWRT \"$PASSPHRASE_METAWRT\"" >> "$TEMP_ENV_FILE"
    echo "" >> "$TEMP_ENV_FILE"
    
    echo "$green""Passphrases generated successfully and stored in temporary file.""$reset"
    echo "$yellow""IMPORTANT: Please encrypt these passphrases using:""$reset"
    echo "  $argv[0] encrypt"
    echo ""
    echo "$yellow""To view the generated passphrases:""$reset"
    echo "  cat $TEMP_ENV_FILE"
end

function encrypt_passphrases
    if not test -f "$TEMP_ENV_FILE"
        echo "$red""Error: No temporary passphrase file found at $TEMP_ENV_FILE""$reset"
        echo "Generate passphrases first using:"
        echo "  $argv[0] generate [length]"
        return 1
    end
    
    # Get encryption password
    read -P "Enter encryption password: " -s password
    echo ""
    read -P "Confirm password: " -s password_confirm
    echo ""
    
    if test "$password" != "$password_confirm"
        echo "$red""Error: Passwords do not match.""$reset"
        return 1
    end
    
    # Generate salt
    set salt (generate_salt)
    
    # Ensure directory exists
    mkdir -p (dirname "$PASSPHRASE_FILE")
    
    # Encrypt file
    cat "$TEMP_ENV_FILE" | openssl enc -aes-256-cbc -salt -pbkdf2 -iter 10000 \
        -pass pass:"$salt$password" -out "$PASSPHRASE_FILE" 2>/dev/null
        
    if test $status -eq 0
        # Secure the file
        chmod 600 "$PASSPHRASE_FILE"
        
        # Remove temporary file
        rm "$TEMP_ENV_FILE"
        
        echo "$green""Passphrases encrypted successfully to $PASSPHRASE_FILE""$reset"
        echo "$yellow""The passphrase file is encrypted with your password.""$reset"
        echo "To load these passphrases into the environment:"
        echo "  $argv[0] decrypt"
    else
        echo "$red""Encryption failed.""$reset"
        return 1
    end
end

function decrypt_to_env
    if not test -f "$PASSPHRASE_FILE"
        echo "$red""Error: No encrypted passphrase file found at $PASSPHRASE_FILE""$reset"
        return 1
    end
    
    # Get decryption password
    read -P "Enter decryption password: " -s password
    echo ""
    
    # Get salt
    set salt (generate_salt)
    
    # Decrypt to temporary file
    openssl enc -aes-256-cbc -d -salt -pbkdf2 -iter 10000 \
        -pass pass:"$salt$password" -in "$PASSPHRASE_FILE" -out "$TEMP_ENV_FILE" 2>/dev/null
        
    if test $status -eq 0
        # Set secure permissions
        chmod 600 "$TEMP_ENV_FILE"
        
        echo "$green""Passphrases decrypted successfully. Loading into environment...""$reset"
        source "$TEMP_ENV_FILE"
        
        # Export passphrases to a file that can be sourced by the main script
        set ENV_EXPORT_FILE "$BASE_DIR/passphrases.fish"
        cp "$TEMP_ENV_FILE" "$ENV_EXPORT_FILE"
        chmod 600 "$ENV_EXPORT_FILE"
        
        # Remove temporary file
        rm "$TEMP_ENV_FILE"
        
        echo "$green""Passphrases loaded into environment successfully.""$reset"
        echo "$green""Exported passphrases to $ENV_EXPORT_FILE for the installer to use.""$reset"
        echo "$yellow""WARNING: The exported file contains unencrypted passphrases.""$reset"
        echo "$yellow""DELETE this file after installation is complete.""$reset"
    else
        echo "$red""Decryption failed. Incorrect password?""$reset"
        return 1
    end
end

# Main command processing
if test (count $argv) -eq 0
    show_help
    exit 0
end

switch $argv[1]
    case "help"
        show_help
    
    case "generate"
        if test (count $argv) -gt 1
            generate_passphrases $argv[2]
        else
            generate_passphrases 32
        end
    
    case "encrypt"
        encrypt_passphrases
    
    case "decrypt"
        decrypt_to_env
    
    case "*"
        echo "$red""Unknown command: $argv[1]""$reset"
        show_help
        exit 1
end

exit 0