# WireGuard Connection Guidelines

## SSH Access via WireGuard

When accessing the router via SSH through WireGuard, always use the internal WireGuard IP address:

```bash
ssh root@10.255.0.1 -p 6622
```

## Why Using WireGuard IP Works Best

Using the WireGuard IP (10.255.0.1) ensures proper routing because:

1. **Interface Specificity**: SSH server (Dropbear) is configured to listen on specific interfaces (core and wireguard).
   
2. **Interface Routing**: When connected through WireGuard, you're on a separate virtual network (10.255.0.0/24).
   
3. **Connection Flow**: Using 10.255.0.1 ensures packets flow through the correct interface and get processed by the proper firewall rules.

## Mobile vs. Local Connections

There's a key difference in connection behavior:

1. **When Connected via Local Network (ClosedWrt):**
   - Traffic never leaves your router
   - All routing happens internally
   - Traffic flows directly through internal interfaces

2. **When Connected via Mobile Network:**
   - Traffic traverses the internet before reaching your router
   - WireGuard creates an encrypted tunnel through your mobile provider
   - Explicit interface routing becomes critical
   - PersistentKeepalive is needed to maintain connections

## Optimization for Mobile Connections

To ensure reliable connections from mobile devices:

1. **Add PersistentKeepalive**: Ensure your WireGuard client config includes:
   ```
   PersistentKeepalive = 25
   ```

2. **Use Direct IP**: Always connect using the WireGuard IP address:
   ```
   ssh root@10.255.0.1 -p 6622
   ```

## Troubleshooting Connections

If you have connection issues:

1. Run the diagnostic tool:
   ```
   fish /root/Firmware/scripts/wg-debug.sh
   ```

2. Verify the SSH server is listening on the WireGuard interface:
   ```
   uci show dropbear | grep Interface
   ```
   Should display: `dropbear.@dropbear[0].Interface='core wireguard'`

3. If you're still having issues, try:
   ```
   ssh -v root@10.255.0.1 -p 6622
   ```
   The `-v` flag provides verbose output for troubleshooting.

## Connection Security

All WireGuard traffic is encrypted and requires proper key authentication. FastWrt's WireGuard setup:

1. Uses private key authentication
2. Properly masquerades traffic through WAN
3. Applies firewall rules that reject unauthorized access attempts with informative errors
4. Only accepts connections from authorized peers defined in the configuration
