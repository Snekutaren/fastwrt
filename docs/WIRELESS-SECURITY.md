# Wireless Security in FastWrt

FastWrt implements a comprehensive wireless security strategy with different security levels based on the purpose of each network.

## Wireless Network Security Overview

| Network    | Band      | Encryption | Purpose                         | Notes                           |
|------------|-----------|------------|--------------------------------|----------------------------------|
| ClosedWrt  | 2.4G & 5G | WPA2-PSK   | Primary network for trusted devices | MAC filtered, isolates by default |
| OpenWrt    | 2.4G & 5G | WPA2-PSK   | General purpose access         | MAC filtered, isolates by default |
| IoTWrt     | 2.4G only | WPA2-PSK   | IoT devices with limited internet | Heavy isolation, restricted traffic |
| MetaWrt    | 5G only   | WPA3-SAE   | High-security network segment  | Enhanced encryption, MAC filtered |

## Encryption Types

FastWrt uses different encryption methods based on security requirements and device compatibility:

1. **WPA2-PSK (psk2)**: Used for most networks to balance security and compatibility
   - Strong security suitable for most use cases
   - Compatible with virtually all modern devices
   - Uses AES/CCMP encryption

2. **WPA3-SAE (sae)**: Used for MetaWrt network for enhanced security
   - Offers stronger protection against password cracking
   - Implements Simultaneous Authentication of Equals (SAE)
   - Provides forward secrecy
   - Limited to newer devices that support WPA3

## MAC Address Filtering

All wireless networks in FastWrt use MAC address filtering for additional security:

- MAC filtering is **enabled by default** on all networks (ClosedWrt, OpenWrt, IoTWrt, and MetaWrt)
- Only devices with MAC addresses listed in `maclist.csv` can connect
- Core network devices are automatically allowed on all networks
- The configuration initializes MAC filtering as 'disabled' first, then enables it after populating MAC lists

To manage MAC filtering:
1. Edit the `maclist.csv` file to add/remove devices
2. Run the configuration script to apply changes
3. Use the included management script to temporarily disable filtering if needed:
   ```bash
   ./manage_mac_filtering.sh [enable|disable|status]
   ```

## How MAC Filtering is Applied

The system applies MAC filtering in the following sequence:

1. Each wireless interface is initially configured with `macfilter='disable'`
2. MAC addresses from `maclist.csv` are processed and added to appropriate interfaces
3. Core device MACs are added to all networks for seamless roaming
4. After populating all MAC lists, `macfilter='allow'` is set for all interfaces
5. This ensures no disruption during configuration updates

## Best Practices

1. **Password Strength**: Use strong, unique passphrases for each network
2. **Regular Updates**: Update the router firmware regularly
3. **Guest Network**: Use the guest network for untrusted devices
4. **IoT Isolation**: Keep IoT devices on their dedicated network
5. **WPA3 Adoption**: Move devices to the WPA3 network as they become compatible

## Client Compatibility

### WPA3 Compatibility

The MetaWrt network uses WPA3, which requires client device support. The following devices typically support WPA3:

- Android devices running Android 10 or newer
- iOS devices running iOS 13 or newer
- Windows devices with Windows 10 (1903) or newer
- Newer Linux distributions with wpa_supplicant 2.9 or later
- Most devices manufactured after 2019

Devices without WPA3 support should use the WPA2 networks (ClosedWrt, OpenWrt, or IoTWrt).

## Migration Strategy

When migrating to higher security standards, follow these guidelines:

1. **Testing WPA3 Compatibility**: Before moving a device to MetaWrt, verify it supports WPA3-SAE
   - Some devices may claim WPA3 support but have implementation issues
   - Test connectivity before full migration

2. **Phased Approach**:
   - Start with non-critical devices when testing WPA3
   - Monitor for connection issues or stability problems
   - Document compatible and incompatible devices

3. **Fallback Options**:
   - Always maintain WPA2 networks for devices that cannot use WPA3
   - Consider MAC filtering to ensure only known devices can connect

## Troubleshooting Security Features

### WPA3 Connection Issues

If devices have trouble connecting to the WPA3 MetaWrt network:

1. Verify device firmware is up to date
2. Check if the device supports pure SAE or only transitional mode
3. Examine router logs for authentication failures
4. As a temporary measure, connect to a WPA2 network instead

### MAC Filtering Management

The MAC filtering system can be managed with:

```bash
./manage_mac_filtering.sh [enable|disable|status]
```

This script provides a quick way to temporarily disable MAC filtering when adding new devices.

## Future Security Enhancements

FastWrt is committed to following wireless security best practices. Future updates may include:

1. WPA3 transition mode for backward compatibility
2. Enhanced wireless intrusion detection
3. Additional isolation options between wireless clients
4. Automated wireless security auditing
