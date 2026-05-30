#!/usr/bin/env bash
set -euo pipefail

# Hyprland Monitor Manager
# Automatically manages workspace placement based on connected monitors

# Monitor descriptions
MONITOR_A_DESC="LG Electronics LG HDR 4K 0x0007807F"
MONITOR_B_DESC="LG Electronics LG HDR 4K 0x0007FDE4"

# Target user configuration
TARGET_USER="${SUDO_USER:-${USER}}"
TARGET_UID="$(id -u "$TARGET_USER")"
RUNTIME_DIR="/run/user/${TARGET_UID}"
HYPRLAND_SOCKET="${RUNTIME_DIR}/hypr"

# Logging
LOG_TAG="hypr-monitor-manager"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [$LOG_TAG] $*" | logger -t "$LOG_TAG"
    echo "[$LOG_TAG] $*" >&2
}

# Function to execute Hyprland commands
hypr_cmd() {
    local cmd="$1"
    # Use hyprctl directly - much simpler and more reliable
    hyprctl "$cmd" 2>/dev/null || true
}

# Function to get connected monitors
get_connected_monitors() {
    hypr_cmd "monitors" | grep -E "^Monitor" | awk '{print $2}' || true
}

# Function to check if a monitor is connected by description
is_monitor_connected() {
    local target_desc="$1"
    hypr_cmd "monitors" | grep -q "$target_desc" 2>/dev/null
}

# Function to get monitor name by description
get_monitor_name_by_desc() {
    local target_desc="$1"
    # Find the monitor block containing the description and extract the monitor name
    hypr_cmd "monitors" | grep -B 2 "$target_desc" | grep "^Monitor" | awk '{print $2}' || true
}

# Function to move workspaces to a monitor
move_workspaces_to_monitor() {
    local monitor="$1"
    shift
    local workspaces=("$@")
    
    for ws in "${workspaces[@]}"; do
        log "Moving workspace $ws to monitor $monitor"
        hyprctl dispatch moveworkspacetomonitor "$ws" "$monitor" 2>/dev/null || true
        sleep 0.1  # Small delay to prevent flooding
    done
}

# Function to configure monitor layout when external monitors are connected
setup_external_layout() {
    local monitor_a_name monitor_b_name
    
    # Get monitor names
    monitor_a_name=$(get_monitor_name_by_desc "$MONITOR_A_DESC")
    monitor_b_name=$(get_monitor_name_by_desc "$MONITOR_B_DESC")
    
    log "Setting up external monitor layout"
    log "Monitor A: $monitor_a_name, Monitor B: $monitor_b_name"
    
    if [[ -n "$monitor_a_name" ]]; then
        # Move workspaces 1-5 to Monitor A
        move_workspaces_to_monitor "$monitor_a_name" 1 2 3 4 5
    fi
    
    if [[ -n "$monitor_b_name" ]]; then
        # Move workspaces 6-8 to Monitor B
        move_workspaces_to_monitor "$monitor_b_name" 6 7 8
    fi
}

# Function to move all workspaces back to laptop screen
setup_laptop_only_layout() {
    local laptop_monitor
    
    # Get the built-in monitor (usually eDP-1 or similar)
    laptop_monitor=$(get_connected_monitors | grep -E "(eDP|LVDS|DSI)" | head -n1)
    
    if [[ -z "$laptop_monitor" ]]; then
        # Fallback: get the first available monitor
        laptop_monitor=$(get_connected_monitors | head -n1)
    fi
    
    if [[ -n "$laptop_monitor" ]]; then
        log "Moving all workspaces back to laptop monitor: $laptop_monitor"
        move_workspaces_to_monitor "$laptop_monitor" 1 2 3 4 5 6 7 8 9 10
    else
        log "Warning: Could not identify laptop monitor"
    fi
}

# Main function to handle monitor changes
handle_monitor_change() {
    local action="${1:-auto}"
    
    # Give Hyprland a moment to detect the monitor change
    sleep 2
    
    # Check current monitor status
    local monitor_a_connected monitor_b_connected
    
    monitor_a_connected=false
    monitor_b_connected=false
    
    if is_monitor_connected "$MONITOR_A_DESC"; then
        monitor_a_connected=true
        log "Monitor A is connected"
    fi
    
    if is_monitor_connected "$MONITOR_B_DESC"; then
        monitor_b_connected=true
        log "Monitor B is connected"
    fi
    
    # Decide layout based on connected monitors
    if [[ "$monitor_a_connected" == true ]] || [[ "$monitor_b_connected" == true ]]; then
        setup_external_layout
    else
        setup_laptop_only_layout
    fi
}

# Handle different invocation modes
case "${1:-auto}" in
    "add"|"connect")
        log "Monitor connected event"
        handle_monitor_change
        ;;
    "remove"|"disconnect")
        log "Monitor disconnected event"
        handle_monitor_change
        ;;
    "auto"|"")
        log "Auto-detecting monitor configuration"
        handle_monitor_change
        ;;
    "setup-external")
        log "Manually setting up external layout"
        setup_external_layout
        ;;
    "setup-laptop")
        log "Manually setting up laptop-only layout"
        setup_laptop_only_layout
        ;;
    "status")
        echo "Connected monitors:"
        get_connected_monitors
        echo
        echo "Monitor A connected: $(is_monitor_connected "$MONITOR_A_DESC" && echo "Yes" || echo "No")"
        echo "Monitor B connected: $(is_monitor_connected "$MONITOR_B_DESC" && echo "Yes" || echo "No")"
        ;;
    *)
        echo "Usage: $0 [add|remove|auto|setup-external|setup-laptop|status]"
        echo
        echo "Commands:"
        echo "  add/connect     - Handle monitor connection"
        echo "  remove/disconnect - Handle monitor disconnection"
        echo "  auto            - Auto-detect and configure (default)"
        echo "  setup-external  - Manually setup external monitor layout"
        echo "  setup-laptop    - Manually setup laptop-only layout"
        echo "  status          - Show current monitor status"
        exit 1
        ;;
esac
