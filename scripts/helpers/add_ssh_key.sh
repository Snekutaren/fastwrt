#!/bin/bash
# FastWrt SSH Key Management Utility

# Set colors for better readability
BLUE='\033[0;34m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Define the keys directory
KEYS_DIR="./ssh_keys"
FIRST_BOOT_SCRIPT="./scripts/99-first-boot.sh"

# Create the keys directory if it doesn't exist
mkdir -p "$KEYS_DIR"

echo -e "${BLUE}FastWrt SSH Key Management Utility${NC}"
echo "=============================="
echo ""
echo "This utility helps you add SSH keys to your FastWrt firmware build."
echo ""

# Function to add a key from a file
add_key_from_file() {
    local key_file="$1"
    local key_name="$2"
    
    if [ ! -f "$key_file" ]; then
        echo -e "${RED}Error: Key file $key_file doesn't exist${NC}"
        return 1
    fi
    
    # Validate that this is an SSH public key
    if ! grep -q "ssh-" "$key_file"; then
        echo -e "${RED}Error: $key_file doesn't appear to be a valid SSH public key${NC}"
        return 1
    fi
    
    # Copy the key to the ssh_keys directory
    cp "$key_file" "$KEYS_DIR/$key_name"
    echo -e "${GREEN}Key successfully added to $KEYS_DIR/$key_name${NC}"
    
    # Update the first-boot script with all available keys
    update_first_boot_script
    
    return 0
}

# Function to generate a new key pair
generate_new_key() {
    local key_name="$1"
    
    echo "Generating a new SSH key pair named $key_name"
    ssh-keygen -t ed25519 -f "$KEYS_DIR/$key_name" -N ""
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Key pair successfully generated:${NC}"
        echo "Private key: $KEYS_DIR/$key_name"
        echo "Public key: $KEYS_DIR/$key_name.pub"
        
        # Update the first-boot script with all available keys
        update_first_boot_script
    else
        echo -e "${RED}Error generating SSH key pair${NC}"
        return 1
    fi
    
    return 0
}

# Function to update the first-boot script with all available keys
update_first_boot_script() {
    if [ ! -f "$FIRST_BOOT_SCRIPT" ]; then
        echo -e "${RED}Error: First boot script not found at $FIRST_BOOT_SCRIPT${NC}"
        return 1
    fi
    
    # Create a temporary file
    local temp_file=$(mktemp)
    
    # Count available public keys
    local key_count=$(find "$KEYS_DIR" -name "*.pub" | wc -l)
    
    if [ $key_count -eq 0 ]; then
        echo -e "${YELLOW}Warning: No public keys found in $KEYS_DIR${NC}"
        echo -e "${YELLOW}The first-boot script will not be updated${NC}"
        return 1
    fi
    
    echo -e "${BLUE}Found $key_count public key(s). Updating first-boot script...${NC}"
    
    # Process the script and replace the SSH key section
    awk -v key_dir="$KEYS_DIR" '
    BEGIN {
        in_key_section = 0
        key_section_replaced = 0
    }
    
    # Detect the start of the key section
    /cat << '\''EOF'\'' > \/etc\/dropbear\/authorized_keys/ {
        in_key_section = 1
        print $0
        
        # Add all keys from the directory
        system("find \"" key_dir "\" -name \"*.pub\" -type f -exec cat {} \\;")
        
        # Skip the actual key content in the script
        next
    }
    
    # Detect the end of the key section
    /^EOF/ {
        if (in_key_section) {
            in_key_section = 0
            key_section_replaced = 1
            print $0
            next
        }
    }
    
    # Skip lines in the key section
    in_key_section {
        next
    }
    
    # Print all other lines
    {
        print $0
    }
    ' "$FIRST_BOOT_SCRIPT" > "$temp_file"
    
    # Replace the original file
    mv "$temp_file" "$FIRST_BOOT_SCRIPT"
    
    echo -e "${GREEN}First boot script updated with all SSH keys from $KEYS_DIR${NC}"
    chmod +x "$FIRST_BOOT_SCRIPT"
    
    return 0
}

# Function to show current keys
show_current_keys() {
    echo -e "${BLUE}Current SSH keys:${NC}"
    
    if [ ! "$(ls -A $KEYS_DIR 2>/dev/null)" ]; then
        echo "No keys found in $KEYS_DIR"
        return 0
    fi
    
    for key in "$KEYS_DIR"/*.pub; do
        if [ -f "$key" ]; then
            echo -e "${GREEN}$(basename "$key"):${NC}"
            ssh-keygen -lf "$key"
            echo ""
        fi
    done
    
    return 0
}

# Function to check if the keys are integrated in the first boot script
check_integration() {
    if [ ! -f "$FIRST_BOOT_SCRIPT" ]; then
        echo -e "${RED}Error: First boot script not found at $FIRST_BOOT_SCRIPT${NC}"
        return 1
    fi
    
    # Count available public keys
    local key_count=$(find "$KEYS_DIR" -name "*.pub" | wc -l)
    
    if [ $key_count -eq 0 ]; then
        echo -e "${YELLOW}No public keys found in $KEYS_DIR${NC}"
        echo -e "${RED}Warning: You will not have SSH key access to your router!${NC}"
        echo -e "${RED}Password authentication will be enabled by default.${NC}"
    else
        echo -e "${GREEN}Found $key_count SSH key(s) ready for deployment${NC}"
        
        # Check if first-boot script still contains the placeholder key
        if grep -q "YOUR_SSH_PUBLIC_KEY_HERE" "$FIRST_BOOT_SCRIPT"; then
            echo -e "${YELLOW}First boot script contains placeholder SSH key.${NC}"
            echo -e "${YELLOW}Run option 5 to update the script with your keys.${NC}"
        else
            echo -e "${GREEN}First boot script has been updated with your keys.${NC}"
        fi
    fi
    
    return 0
}

# Main menu
while true; do
    echo ""
    echo -e "${BLUE}FastWrt SSH Key Management Options:${NC}"
    echo "1. Add an existing SSH public key"
    echo "2. Generate a new SSH key pair"
    echo "3. Show current SSH keys" 
    echo "4. Check key integration status"
    echo "5. Update first-boot script with all keys"
    echo "6. Exit"
    echo ""
    read -p "Select an option (1-6): " choice
    
    case $choice in
        1)
            echo ""
            read -p "Enter the path to your SSH public key file: " key_file
            read -p "Enter a name for this key (default: fastwrt_key.pub): " key_name
            key_name=${key_name:-fastwrt_key.pub}
            add_key_from_file "$key_file" "$key_name"
            ;;
        2)
            echo ""
            read -p "Enter a name for the new key (default: fastwrt_key): " key_name
            key_name=${key_name:-fastwrt_key}
            generate_new_key "$key_name"
            ;;
        3)
            echo ""
            show_current_keys
            ;;
        4)
            echo ""
            check_integration
            ;;
        5)
            echo ""
            update_first_boot_script
            ;;
        6)
            echo -e "${GREEN}Exiting. Your SSH keys are stored in $KEYS_DIR${NC}"
            break
            ;;
        *)
            echo -e "${RED}Invalid option. Please select 1-6${NC}"
            ;;
    esac
done

# Display final instructions
echo ""
echo -e "${YELLOW}Important: ${NC}"
echo "1. Your SSH public keys are stored in the $KEYS_DIR directory."
echo "2. These keys will be embedded in the firmware build."
echo "3. After flashing the firmware, you can connect using your SSH key."
echo "4. Password authentication will be disabled for better security."
echo ""

# Final check for key integration
check_integration