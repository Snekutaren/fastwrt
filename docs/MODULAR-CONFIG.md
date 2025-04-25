# Modular Configuration System for FastWrt

This document outlines the planned modular configuration system for FastWrt, which will allow more flexible and maintainable configuration management through structured configuration directories.

## Proposed Directory Structure

FastWrt/
├── Firmware/
│   ├── config/ # Main configuration directory
│   │   ├── config_paths.fish # Central config file defining paths
│   │   ├── defaults/ # Default configuration values
│   │   │   ├── network.fish # Default network settings
│   │   │   ├── wireless.fish # Default wireless settings
│   │   │   └── firewall.fish # Default firewall settings
│   │   ├── devices/ # Device-specific configurations
│   │   │   ├── GL-MT300N-V2/ # Router model-specific configs
│   │   │   ├── Linksys-WRT3200ACM/ # Another router model
│   │   │   └── ... # More device folders
│   │   ├── networks/ # Network profiles
│   │   │   ├── home/ # Home network profile
│   │   │   ├── office/ # Office network profile
│   │   │   └── travel/ # Travel router profile
│   │   ├── wireless/ # Wireless configuration
│   │   │   ├── ssid_profiles/ # SSID naming schemes
│   │   │   └── security/ # Encryption settings
│   │   ├── firewall/ # Firewall rules and zones
│   │   │   ├── standard/ # Standard security level
│   │   │   └── strict/ # Stricter security rules
│   │   └── users/ # User configurations
│   │       └── john/ # User-specific overrides
│   ├── scripts/ # Existing scripts directory
│   └── ... # Other directories

## Benefits of Modular Configuration

1. **Flexibility**: Easily switch between different network profiles
2. **Reusability**: Share configurations between different installations
3. **Maintainability**: Organize settings by function and purpose
4. **Version Control**: Better tracking of configuration changes
5. **Multiple Deployment Support**: Support different environments with minimal changes

## Implementation Strategy

To implement this modular approach while maintaining backward compatibility:

1. **Gradual Migration**: Begin with a hybrid approach that supports both current and modular configurations
2. **Device Profiles**: Create device-specific profiles to handle hardware differences
3. **Network Profiles**: Define different network layouts (home, office, travel, etc.)
4. **Common Base**: Maintain a set of common defaults that apply across all profiles
5. **Override System**: Implement a clear hierarchy of configuration overrides

## Central Configuration Management

The core of the modular system is a configuration manager that:

1. Loads the base configuration
2. Applies device-specific overrides
3. Loads the selected network profile
4. Applies user customizations
5. Validates the resulting configuration for consistency

## Example Profile: Home Router

A typical home router profile includes:

- Multiple segmented networks (core, guest, IoT)
- Strong encryption for all wireless networks
- WPA3 for high-security networks
- MAC filtering for restricted networks
- Custom DHCP options for different network segments

## Example Profile: Travel Router

A travel router profile includes:

- Simplified network layout (one or two networks)
- Optimized for battery life
- Different DNS settings for public Wi-Fi environments
- VPN configurations for secure connectivity
- More permissive firewall settings for hotspot connectivity

## Configuration Loading Process

The system follows a clear precedence order:

1. Base defaults (lowest priority)
2. Device-specific settings
3. Network profile settings
4. User customizations (highest priority)

This ensures that more specific configurations override general ones while maintaining a consistent base.

## Configuration File Format

Each configuration file is a Fish shell compatible file containing environment variables:

```fish
# Example wireless.fish in defaults directory
set -gx SSID_PREFIX "FastWrt"
set -gx DEFAULT_ENCRYPTION "psk2"
set -gx DEFAULT_CHANNEL_2G "6"
set -gx DEFAULT_CHANNEL_5G "36"
```

## Sample Implementation

Here's how the configuration loading works in scripts:

```fish
# First load defaults
source "$CONFIG_DIR/defaults/network.fish"
source "$CONFIG_DIR/defaults/wireless.fish"

# Then load device-specific overrides if they exist
if test -f "$CONFIG_DIR/devices/$DEVICE_MODEL/wireless.fish"
    source "$CONFIG_DIR/devices/$DEVICE_MODEL/wireless.fish"
end

# Load network profile
if test -f "$CONFIG_DIR/networks/$NETWORK_PROFILE/wireless.fish"
    source "$CONFIG_DIR/networks/$NETWORK_PROFILE/wireless.fish"
end

# Finally, load user overrides
if test -f "$CONFIG_DIR/users/$USER_PROFILE/wireless.fish"
    source "$CONFIG_DIR/users/$USER_PROFILE/wireless.fish"
end
```

## Configuration Selection

A main configuration file config_paths.fish controls which profiles are used:

```fish
# Sample config_paths.fish
set -gx DEVICE_MODEL "GL-MT300N-V2"
set -gx NETWORK_PROFILE "home"
set -gx USER_PROFILE "john"
```

## Implementation Phases

### Phase 1: Directory Structure and Base Configuration

- Create the directory structure as outlined above
- Extract current configuration settings into default fish files
- Add support for detecting and loading modular configurations
- Update scripts to check for modular configurations first, falling back to current approach

### Phase 2: Device Profile Support

- Create device profiles for common router models
- Implement device detection mechanism
- Add device-specific optimizations and configurations
- Develop testing framework for device profiles

### Phase 3: Network Profile Development

- Create standard network profiles (home, office, travel)
- Implement profile selection mechanism
- Develop documentation for creating custom profiles
- Build validation tools for profile integrity

### Phase 4: User Interface and Management

- Create a simple web interface for profile selection and customization
- Build command-line tools for managing profiles
- Implement configuration visualization tools
- Develop backup and restore functionality for profiles

## Migration Path for Existing Installations

For existing FastWrt installations, we'll provide:

- A migration script to extract current configuration into modular format
- Documentation explaining the transition process
- Backward compatibility layer to ensure existing configurations continue working
- Option to revert to non-modular approach if needed

## Future Expansion Possibilities

- Profile Repository: Centralized repository of community-contributed profiles
- Automated Device Detection: Intelligent device type recognition
- Template System: Create new profiles based on existing templates
- Configuration Wizard: Guided setup for common scenarios
- Export/Import: Share configurations between installations

## Conclusion

The modular configuration system will significantly enhance FastWrt's flexibility and maintainability while preserving its core security focus. By separating configuration by function, device, and environment, we enable more targeted customization without sacrificing consistency or security.