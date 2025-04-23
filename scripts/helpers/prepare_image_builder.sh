#!/bin/bash
# FastWrt Image Builder Preparation Script

# Set colors for better readability
BLUE='\033[0;34m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}FastWrt Image Builder Preparation Script${NC}"
echo "======================================"
echo ""

# Check for OpenWrt Image Builder path argument
if [ $# -lt 1 ]; then
    echo -e "${RED}Error: Missing OpenWrt Image Builder path${NC}"
    echo "Usage: $0 <path_to_image_builder>"
    echo "Example: $0 ~/openwrt-imagebuilder-22.03.3-ramips-mt7621.Linux-x86_64"
    exit 1
fi

IMAGE_BUILDER_PATH="$1"

# Verify Image Builder path exists
if [ ! -d "$IMAGE_BUILDER_PATH" ]; then
    echo -e "${RED}Error: Image Builder path does not exist: $IMAGE_BUILDER_PATH${NC}"
    exit 1
fi

echo "Using OpenWrt Image Builder at: $IMAGE_BUILDER_PATH"
echo ""

# Create necessary directories
echo "Creating necessary directories..."
FILES_DIR="$IMAGE_BUILDER_PATH/files"
UCI_DEFAULT_DIR="$FILES_DIR/etc/uci-defaults"
SSH_DIR="$FILES_DIR/etc/dropbear"
BACKUP_DIR="$FILES_DIR/etc/config/backups"

mkdir -p "$UCI_DEFAULT_DIR"
mkdir -p "$SSH_DIR"
mkdir -p "$BACKUP_DIR"

# Check for SSH keys
echo "Checking for SSH keys..."
if [ ! "$(ls -A ./ssh_keys/*.pub 2>/dev/null)" ]; then
    echo -e "${YELLOW}Warning: No SSH keys found in ./ssh_keys/!${NC}"
    echo "You should add at least one SSH key before building the firmware."
    echo "Run ./add_ssh_key.sh to add or generate SSH keys."
    echo ""
    read -p "Do you want to continue anyway? (y/n): " continue_anyway
    
    if [ "$continue_anyway" != "y" ]; then
        echo "Aborting. Please add SSH keys using ./add_ssh_key.sh first."
        exit 1
    fi
else
    echo -e "${GREEN}SSH keys found. Will use them in the firmware build.${NC}"
fi

# Copy first-boot script to uci-defaults directory
echo "Copying first-boot script to uci-defaults..."
cp ./scripts/99-first-boot.sh "$UCI_DEFAULT_DIR/"
chmod +x "$UCI_DEFAULT_DIR/99-first-boot.sh"

# Copy SSH keys to dropbear directory
echo "Copying SSH keys to dropbear directory..."
cat ./ssh_keys/*.pub > "$SSH_DIR/authorized_keys"
chmod 600 "$SSH_DIR/authorized_keys"

# Create a list of packages
echo "Creating package list for Image Builder..."
PACKAGE_LIST=$(grep -v '^#' ./packages | tr -d ' ' | tr '\n' ' ')

echo -e "${GREEN}Preparation completed successfully!${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Navigate to your OpenWrt Image Builder directory:"
echo "   cd $IMAGE_BUILDER_PATH"
echo ""
echo "2. Build your firmware with this command:"
echo "   make image PROFILE=glinet_gl-mt6000 PACKAGES=\"$PACKAGE_LIST\" FILES=files/"
echo ""
echo "3. Flash the resulting firmware to your router"
echo ""
echo -e "${YELLOW}Important:${NC}"
echo "- SSH password authentication will be disabled on the first boot"
echo "- Access will only be possible using your SSH key"
echo "- If you lose your SSH key, you'll need to reset the router to factory defaults"
echo ""