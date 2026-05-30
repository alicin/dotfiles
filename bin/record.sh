#!/bin/bash

# Screen recording script with cross-platform support
# Supports wf-recorder (Wayland) and other recording tools

set -e

# Source utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../lib/logging.sh"
source "${SCRIPT_DIR}/../../lib/os-detection.sh"

# Configuration
VIDEOS_DIR="${HOME}/Videos"
TEMP_FILE="/tmp/recording.txt"
TIMESTAMP="$(date +%Y-%m-%d_%H-%M-%S)"

# Ensure videos directory exists
mkdir -p "$VIDEOS_DIR"

# Check if recording is already running
check_recording() {
	if pgrep -x "wf-recorder" > /dev/null; then
		log_info "Stopping existing recording..."
		pkill -INT -x wf-recorder
		
		if [[ -f "$TEMP_FILE" ]]; then
			local video_file="$(cat "$TEMP_FILE")"
			log_success "Recording saved to: $video_file"
			
			# Copy file path to clipboard if available
			if command -v wl-copy >/dev/null 2>&1; then
				echo "$video_file" | wl-copy
				log_info "File path copied to clipboard"
			elif command -v pbcopy >/dev/null 2>&1; then
				echo "$video_file" | pbcopy
				log_info "File path copied to clipboard"
			fi
			
			# Send notification if available
			if command -v notify-send >/dev/null 2>&1; then
				notify-send "Recording Stopped" "Saved to: $(basename "$video_file")"
			fi
		fi
		exit 0
	fi
}

# Start recording based on platform
start_recording() {
	local video_file="${VIDEOS_DIR}/recording_${TIMESTAMP}.mp4"
	
	if is_linux; then
		if command -v wf-recorder >/dev/null 2>&1 && command -v slurp >/dev/null 2>&1; then
			log_step "Starting Wayland recording..."
			echo "$video_file" > "$TEMP_FILE"
			
			# Let user select area
			local geometry
			if ! geometry="$(slurp)"; then
				log_error "Recording cancelled by user"
				exit 1
			fi
			
			log_info "Recording to: $video_file"
			log_info "Press Ctrl+C or run this script again to stop"
			
			# Start recording in background
			wf-recorder -g "$geometry" -f "$video_file" &
			
			# Wait for recording to start
			sleep 1
			
			if pgrep -x "wf-recorder" > /dev/null; then
				log_success "Recording started successfully"
				if command -v notify-send >/dev/null 2>&1; then
					notify-send "Recording Started" "Press Ctrl+C or run script again to stop"
				fi
			else
				log_error "Failed to start recording"
				exit 1
			fi
		else
			log_error "wf-recorder or slurp not found. Install with:"
			log_info "  Arch: sudo pacman -S wf-recorder slurp"
			log_info "  Fedora: sudo dnf install wf-recorder slurp"
			exit 1
		fi
	elif is_macos; then
		log_error "macOS recording not implemented yet"
		log_info "Use QuickTime Player or install a screen recorder"
		exit 1
	else
		log_error "Unsupported platform: $DETECTED_OS"
		exit 1
	fi
}

# Show help
show_help() {
	echo "Screen Recording Tool"
	echo ""
	echo "Usage: $0 [options]"
	echo ""
	echo "Options:"
	echo "  -h, --help    Show this help"
	echo "  -s, --stop    Stop current recording"
	echo ""
	echo "Examples:"
	echo "  $0            # Start recording (or stop if already running)"
	echo "  $0 --stop     # Force stop recording"
	echo ""
	echo "Platform Support:"
	echo "  Linux (Wayland): wf-recorder + slurp"
	echo "  macOS: Not implemented"
	echo ""
}

# Parse arguments
case "${1:-}" in
	-h|--help)
		show_help
		exit 0
		;;
	-s|--stop)
		check_recording
		log_info "No recording currently running"
		exit 0
		;;
	"")
		# Default behavior: toggle recording
		check_recording
		start_recording
		;;
	*)
		log_error "Unknown option: $1"
		show_help
		exit 1
		;;
esac