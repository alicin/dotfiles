#!/bin/bash

# Screen brightness control script
# Supports Linux (light/brightnessctl) and macOS

set -e

# Source utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../lib/logging.sh"
source "${SCRIPT_DIR}/../../lib/os-detection.sh"

# Configuration
STEP_PERCENT=5
MIN_BRIGHTNESS=1

# Get current brightness percentage
get_brightness() {
    if is_linux; then
        if command -v light >/dev/null 2>&1; then
            light -G
        elif command -v brightnessctl >/dev/null 2>&1; then
            brightnessctl -m | cut -d',' -f4 | tr -d '%'
        else
            log_error "No brightness control tool found. Install 'light' or 'brightnessctl'"
            exit 1
        fi
    elif is_macos; then
        # Use osascript to get display brightness
        osascript -e "tell application \"System Events\" to get the brightness of every screen" | cut -d',' -f1
    else
        log_error "Unsupported platform: $DETECTED_OS"
        exit 1
    fi
}

# Set brightness percentage
set_brightness() {
    local target="$1"
    
    # Ensure target is within bounds
    if (( $(echo "$target < $MIN_BRIGHTNESS" | bc -l) )); then
        target="$MIN_BRIGHTNESS"
    elif (( $(echo "$target > 100" | bc -l) )); then
        target="100"
    fi
    
    if is_linux; then
        if command -v light >/dev/null 2>&1; then
            light -S "$target"
        elif command -v brightnessctl >/dev/null 2>&1; then
            brightnessctl set "${target}%"
        fi
    elif is_macos; then
        osascript -e "tell application \"System Events\" to set brightness of every screen to $target"
    fi
    
    log_info "Brightness set to ${target}%"
}

# Increase brightness
brightness_up() {
    local current
    current="$(get_brightness)"
    local new_brightness
    new_brightness="$(echo "$current + $STEP_PERCENT" | bc -l)"
    
    set_brightness "$new_brightness"
}

# Decrease brightness
brightness_down() {
    local current
    current="$(get_brightness)"
    local new_brightness
    new_brightness="$(echo "$current - $STEP_PERCENT" | bc -l)"
    
    # Special logic for very low brightness
    if (( $(echo "$current <= $(echo "$STEP_PERCENT + 1" | bc -l)" | bc -l) )) && (( $(echo "$current > $MIN_BRIGHTNESS" | bc -l) )); then
        new_brightness="$MIN_BRIGHTNESS"
    fi
    
    set_brightness "$new_brightness"
}

# Show current brightness
show_brightness() {
    local current
    current="$(get_brightness)"
    echo "Current brightness: ${current}%"
}

# Show help
show_help() {
    echo "Brightness Control Tool"
    echo ""
    echo "Usage: $0 [command] [value]"
    echo ""
    echo "Commands:"
    echo "  up              Increase brightness by $STEP_PERCENT%"
    echo "  down            Decrease brightness by $STEP_PERCENT%"
    echo "  set <percent>   Set brightness to specific percentage (1-100)"
    echo "  get             Show current brightness"
    echo ""
    echo "Examples:"
    echo "  $0 up           # Increase brightness"
    echo "  $0 down         # Decrease brightness"
    echo "  $0 set 50       # Set brightness to 50%"
    echo "  $0 get          # Show current brightness"
    echo ""
    echo "Platform Support:"
    echo "  Linux: light or brightnessctl"
    echo "  macOS: osascript (System Events)"
    echo ""
    echo "Dependencies:"
    echo "  Linux: sudo pacman -S light  # or brightnessctl"
    echo "  macOS: No additional dependencies"
    echo ""
}

# Parse arguments
case "${1:-get}" in
    up)
        brightness_up
        show_brightness
        ;;
    down)
        brightness_down
        show_brightness
        ;;
    set)
        if [[ -z "$2" ]]; then
            log_error "Please specify brightness percentage"
            echo "Usage: $0 set <percent>"
            exit 1
        fi
        
        if ! [[ "$2" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
            log_error "Invalid brightness value: $2"
            echo "Please specify a number between 1 and 100"
            exit 1
        fi
        
        set_brightness "$2"
        show_brightness
        ;;
    get|"")
        show_brightness
        ;;
    -h|--help)
        show_help
        exit 0
        ;;
    *)
        log_error "Unknown command: $1"
        show_help
        exit 1
        ;;
esac