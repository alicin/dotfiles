# Hyprland Monitor Manager

Automatic workspace management for Hyprland based on monitor connection status.

## Overview

This system automatically moves workspaces between monitors when external displays are connected or disconnected:

- **Workspaces 1-5**: Move to Monitor A (LG HDR 4K 0x0007807F) when connected
- **Workspaces 6-8**: Move to Monitor B (LG HDR 4K 0x0007FDE4) when connected
- **All workspaces**: Move back to laptop screen when external monitors are disconnected

## Components

### Scripts

- `bin/hypr-monitor-manager.sh` - Main monitor management script
- `scripts/monitor-manager.sh` - Installation script for udev rules

### Monitor Identification

The system identifies external monitors by their descriptions:

- **Monitor A**: `LG Electronics LG HDR 4K 0x0007807F`
- **Monitor B**: `LG Electronics LG HDR 4K 0x0007FDE4`

## Installation

1. Run the installation script as root:

   ```bash
   sudo ./scripts/monitor-manager.sh
   ```

2. The script will:
   - Install udev rules for automatic monitor detection
   - Make the manager script executable
   - Reload udev rules to activate the system

## Manual Usage

You can manually control workspace layout with these commands:

```bash
# Auto-detect and configure based on current monitors
sudo ./bin/hypr-monitor-manager.sh auto

# Force external monitor layout
sudo ./bin/hypr-monitor-manager.sh setup-external

# Force laptop-only layout
sudo ./bin/hypr-monitor-manager.sh setup-laptop

# Show current monitor status
sudo ./bin/hypr-monitor-manager.sh status

# Simulate monitor connection/disconnection for testing
sudo ./bin/hypr-monitor-manager.sh add
sudo ./bin/hypr-monitor-manager.sh remove
```

## How It Works

### Automatic Detection

The system uses udev rules to detect monitor hotplug events:

1. **Monitor Connection**: When a monitor is connected, udev triggers the manager script
2. **Monitor Detection**: Script checks which external monitors are connected
3. **Workspace Movement**: Moves workspaces to appropriate monitors based on configuration
4. **Monitor Disconnection**: When monitors are disconnected, moves all workspaces back to laptop screen

### udev Rules

The system installs rules in `/etc/udev/rules.d/99-hyprland-monitor-hotplug.rules` that detect:

- DRM subsystem changes (monitor connect/disconnect)
- USB-C/Thunderbolt display events
- General display connector changes

### Hyprland Integration

The script communicates with Hyprland using:

- Unix sockets for sending commands
- `moveworkspacetomonitor` command for workspace management
- Monitor detection via `monitors` command

## Logging

Monitor management events are logged to the system journal:

```bash
# Follow monitor manager logs
journalctl -t hypr-monitor-manager -f

# View recent events
journalctl -t hypr-monitor-manager -e
```

## Troubleshooting

### Check Monitor Detection

```bash
# Verify monitors are detected correctly
sudo ./bin/hypr-monitor-manager.sh status
```

### Test Manual Operation

```bash
# Test workspace movement manually
sudo ./bin/hypr-monitor-manager.sh setup-external
sudo ./bin/hypr-monitor-manager.sh setup-laptop
```

### Verify udev Rules

```bash
# Check if rules are installed
ls -la /etc/udev/rules.d/99-hyprland-monitor-hotplug.rules

# Reload rules manually
sudo udevadm control --reload-rules
sudo udevadm trigger --subsystem-match=drm
```

### Debug Hyprland Communication

```bash
# Check if Hyprland socket is accessible
ls -la /run/user/$(id -u)/hypr/

# Test Hyprland command manually
echo "monitors" | socat - UNIX-CONNECT:/run/user/$(id -u)/hypr/*.sock
```

## Uninstallation

To remove the monitor management system:

```bash
# Remove udev rules
sudo rm /etc/udev/rules.d/99-hyprland-monitor-hotplug.rules

# Reload udev
sudo udevadm control --reload-rules
```

## Configuration

To modify the workspace assignments, edit `bin/hypr-monitor-manager.sh`:

- Change monitor descriptions in `MONITOR_A_DESC` and `MONITOR_B_DESC`
- Modify workspace assignments in `setup_external_layout()` function
- Adjust delay timings if needed

## Dependencies

- **Hyprland**: Window manager with IPC support
- **hyprctl**: Hyprland control utility (included with Hyprland)
- **udev**: For automatic monitor detection
- **logger**: For system logging
