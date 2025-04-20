#!/bin/sh

set -e  # Exit on any error

# Log the purpose of the script
echo "Starting settings configuration script to apply system-wide settings..."

### --- System Settings ---
uci -q batch <<EOF
  set system.@system[0].hostname='FastWrt'
  set system.@system[0].timezone='CET-1CEST,M3.5.0,M10.5.0/3'
  set system.@system[0].zonename='Europe/Stockholm'
EOF