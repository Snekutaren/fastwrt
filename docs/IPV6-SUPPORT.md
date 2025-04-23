# IPv6 Support in FastWrt

FastWrt includes optional IPv6 support that can be enabled or disabled based on your network requirements. By default, IPv6 is **disabled** to ensure maximum compatibility and simplicity.

## Current IPv6 Status

The IPv6 support is controlled by the `ENABLE_WAN6` environment variable in the main configuration script.

## Enabling IPv6

To enable IPv6 support:

1. Edit the `01-install.sh` script and find the following line:
   ```bash
   # Option to enable WAN6
   set -gx ENABLE_WAN6 false
   ```

2. Change it to:
   ```bash
   # Option to enable WAN6
   set -gx ENABLE_WAN6 true
   ```

3. Run the configuration script with the standard command:
   ```bash
   ./scripts/etc/uci-defaults/01-install.sh
   ```

## Known IPv6 Issues

When IPv6 is disabled but WAN6 references remain in the firewall configuration, you may see validation warnings like:

