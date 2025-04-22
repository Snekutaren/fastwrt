#!/bin/sh
# Simple launcher script for FastWrt

# Make all scripts executable and then run the installer
chmod -R +x Firmware/*.sh && Firmware/install.sh "$@"