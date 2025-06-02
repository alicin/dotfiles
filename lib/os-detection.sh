#!/bin/bash

# OS Detection utilities
# Usage: source this file and use the detection functions

# Detect operating system
detect_os() {
    case "$(uname -s)" in
        Darwin*)
            echo "macos"
            ;;
        Linux*)
            if command -v pacman >/dev/null 2>&1; then
                echo "arch"
            elif command -v dnf >/dev/null 2>&1; then
                echo "fedora"
            elif command -v apt >/dev/null 2>&1; then
                echo "ubuntu"
            else
                echo "linux"
            fi
            ;;
        CYGWIN*|MINGW32*|MSYS*|MINGW*)
            echo "windows"
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

# Detect architecture
detect_arch() {
    case "$(uname -m)" in
        x86_64)
            echo "x64"
            ;;
        arm64|aarch64)
            echo "arm64"
            ;;
        armv7l)
            echo "arm"
            ;;
        i386|i686)
            echo "x86"
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

# Check if running on macOS
is_macos() {
    [[ "$(detect_os)" == "macos" ]]
}

# Check if running on Linux
is_linux() {
    [[ "$(detect_os)" =~ ^(arch|fedora|ubuntu|linux)$ ]]
}

# Check if running on Arch Linux
is_arch() {
    [[ "$(detect_os)" == "arch" ]]
}

# Check if running on Fedora
is_fedora() {
    [[ "$(detect_os)" == "fedora" ]]
}

# Check if running on ARM architecture
is_arm() {
    [[ "$(detect_arch)" =~ ^(arm64|arm)$ ]]
}

# Export detected values as environment variables
export DETECTED_OS="$(detect_os)"
export DETECTED_ARCH="$(detect_arch)" 