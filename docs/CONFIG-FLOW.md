# FastWrt Configuration Flow

## Overview

The FastWrt configuration process follows a structured flow to ensure that components are configured in the correct order, with dependencies properly managed. This document explains how the configuration scripts interact and how changes are managed.

## Configuration Sequence

1. **Initialization (`01-install.sh`)**
   - Sets up environment variables
   - Loads user configuration
   - Manages script execution order
   - Handles error conditions
   - Commits changes or reverts them based on success

2. **Environment Setup (`02-environment.sh`)**
   - Establishes environment variables for all scripts
   - Sets default values for configuration parameters
   - Ensures consistent settings across all configuration scripts

3. **Backup (`10-backup.sh`)**
   - Creates backups of existing configurations
   - Sets up backup directory structure
   - Archives configuration files with timestamps

4. **System Settings (`20-settings.sh`)**
   - Configures basic system parameters
   - Sets hostname, timezone, and locale
   - Configures fish as the default shell
   - Sets up cron jobs and system passwords

5. **Network Configuration (`30-network.sh`)**
   - Sets up physical interfaces
   - Configures VLANs and bridge devices
   - Establishes network topology

6. **Wireless Setup (`35-wireless.sh`)**
   - Configures radios and wireless interfaces
   - Sets up SSIDs and security
   - Links wireless networks to VLANs
   - Manages MAC filtering for wireless networks

7. **DHCP Configuration (`40-dhcp.sh`)**
   - Configures DHCP servers for each network
   - Sets up DNS resolution
   - Creates static leases from maclist.csv

8. **WireGuard VPN (`45-wireguard.sh`)**
   - Configures secure VPN access
   - Generates keys and sets up interfaces
   - Establishes secure remote access channels

9. **Firewall Rules (`50-firewall.sh`)**
   - Creates security zones
   - Establishes access policies
   - Sets up port forwarding and NAT
   - Configures DNS redirection and security rules

10. **SSH Configuration (`70-dropbear.sh`)**
    - Configures secure SSH access
    - Sets up key-based authentication
    - Restricts SSH access to secure networks

11. **Verification (`80-summary.sh`)**
    - Summarizes pending changes
    - Validates configuration for potential issues
    - Creates logs for troubleshooting
    - Authorizes or denies final commit based on validation

## Dependency Management

FastWrt tracks dependencies between scripts to ensure proper execution order:

```
40-dhcp.sh      → depends on → 30-network.sh
45-wireguard.sh → depends on → 30-network.sh
50-firewall.sh  → depends on → 30-network.sh, 40-dhcp.sh
35-wireless.sh  → depends on → 30-network.sh, 50-firewall.sh
```

If a dependency fails, subsequent scripts that depend on it will be skipped to prevent cascading failures.

## UCI Change Management

All configuration changes are made using UCI (Unified Configuration Interface) commands within individual scripts, but commits are handled centrally:

1. Each script makes its configuration changes using `uci set`, `uci add`, etc.
2. Changes are accumulated in UCI's pending changes queue
3. The `98-commit.sh` script verifies and summarizes all pending changes
4. The main `01-install.sh` script either commits all changes or reverts them based on overall success

This approach ensures:
- Atomic application of configuration (all changes or none)
- Easy rollback if any part of the process fails
- Centralized logging of all changes

> **Note**: For detailed UCI syntax reference, see [UCI-SYNTAX-REFERENCE.md](UCI-SYNTAX-REFERENCE.md)

## Documentation Cross-Reference

FastWrt maintains several documentation files for different aspects of the system:

- **[README.md](../README.md)**: Project overview and general information
- **[NETWORK-DOCUMENTATION.md](NETWORK-DOCUMENTATION.md)**: Detailed network architecture and VLAN structure
- **[UCI-SYNTAX-REFERENCE.md](UCI-SYNTAX-REFERENCE.md)**: Guide to proper UCI syntax patterns
- **CONFIG-FLOW.md** (this file): Configuration process flow and dependencies

Each configuration script also includes inline documentation explaining its specific purpose and operation.

## Debugging and Troubleshooting

FastWrt includes several mechanisms for debugging configuration issues:

1. **Color-coded output** for easy identification of issues:
   - Green: Success
   - Yellow: Warning/Notice
   - Red: Error
   - Blue: Information
   - Purple: Section headers

2. **Debug mode**: Run with `--debug` flag to get verbose output
   ```
   ./scripts/etc/uci-defaults/01-install.sh --debug
   ```

3. **Dry run mode**: Test configuration without applying changes
   ```
   ./scripts/etc/uci-defaults/01-install.sh --dry-run
   ```

4. **Logging**: All output is logged to `/tmp/fastwrt_logs/` for review

## Error Handling

1. **Default behavior**: Stop on first error
   - Prevents cascading failures from incorrect configurations
   - Reverts all changes when an error occurs

2. **Continue mode**: Use `--continue-on-error` flag to attempt to apply all possible configurations
   ```
   ./scripts/etc/uci-defaults/01-install.sh --continue-on-error
   ```

3. **Recovery**: Use backups to restore previous configurations
   ```
   cp /etc/config/backups/network.bak.* /etc/config/network
   ```

## Last Updated
April 24, 2025
