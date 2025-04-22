#!/bin/sh
# Simple launcher script for FastWrt

# Make all scripts executable and then run the installer
chmod -R +x ./*.sh && ./scripts/etc/uci-defaults/01-install.sh "$@"