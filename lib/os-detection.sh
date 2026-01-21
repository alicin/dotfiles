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

# Detect CPU brand
detect_cpu() {
    if [[ -f /proc/cpuinfo ]]; then
        local vendor=$(grep -m1 'vendor_id' /proc/cpuinfo | cut -d: -f2 | tr -d ' ')
        case "$vendor" in
            GenuineIntel)
                echo "intel"
                ;;
            AuthenticAMD)
                echo "amd"
                ;;
            *)
                echo "other"
                ;;
        esac
    elif command -v sysctl >/dev/null 2>&1; then
        # macOS
        local brand=$(sysctl -n machdep.cpu.brand_string 2>/dev/null | tr '[:upper:]' '[:lower:]')
        if [[ "$brand" == *intel* ]]; then
            echo "intel"
        elif [[ "$brand" == *amd* ]]; then
            echo "amd"
        else
            echo "other"
        fi
    else
        echo "other"
    fi
}

# Detect GPU brand (prioritizes dGPU over iGPU)
detect_gpu() {
    if command -v lspci >/dev/null 2>&1; then
        local gpus=$(lspci | grep -iE 'vga|3d|display')
        
        # Check for NVIDIA first (always discrete)
        if echo "$gpus" | grep -qi 'nvidia'; then
            echo "nvidia"
            return
        fi
        
        # Check for AMD discrete GPU (not integrated)
        # AMD discrete GPUs typically show as separate VGA/3D controllers
        local amd_gpus=$(echo "$gpus" | grep -i 'amd\|radeon\|ati')
        local nvidia_count=$(echo "$gpus" | grep -ci 'nvidia' || true)
        local amd_count=$(echo "$amd_gpus" | grep -c . || true)
        
        # If there's an AMD GPU and it's not just an APU integrated graphics
        # Check if there are multiple GPU entries or if AMD is the only one
        if [[ -n "$amd_gpus" ]]; then
            # If AMD is present and there's no Intel iGPU, it's likely discrete or APU
            if ! echo "$gpus" | grep -qi 'intel.*graphics\|intel.*uhd\|intel.*iris'; then
                echo "amd"
                return
            fi
            # If both AMD and Intel exist, AMD is likely discrete
            if echo "$gpus" | grep -qi 'intel' && [[ "$amd_count" -gt 0 ]]; then
                echo "amd"
                return
            fi
        fi
        
        # Check for Intel (usually integrated)
        if echo "$gpus" | grep -qi 'intel'; then
            echo "intel"
            return
        fi
        
        echo "other"
    elif command -v system_profiler >/dev/null 2>&1; then
        # macOS
        local gpu_info=$(system_profiler SPDisplaysDataType 2>/dev/null | tr '[:upper:]' '[:lower:]')
        if echo "$gpu_info" | grep -q 'nvidia'; then
            echo "nvidia"
        elif echo "$gpu_info" | grep -q 'amd\|radeon'; then
            echo "amd"
        elif echo "$gpu_info" | grep -q 'intel'; then
            echo "intel"
        else
            echo "other"
        fi
    else
        echo "other"
    fi
}

# Check if CPU is Intel
is_intel_cpu() {
    [[ "$(detect_cpu)" == "intel" ]]
}

# Check if CPU is AMD
is_amd_cpu() {
    [[ "$(detect_cpu)" == "amd" ]]
}

# Check if GPU is NVIDIA
is_nvidia_gpu() {
    [[ "$(detect_gpu)" == "nvidia" ]]
}

# Check if GPU is AMD
is_amd_gpu() {
    [[ "$(detect_gpu)" == "amd" ]]
}

# Export detected values as environment variables
export DETECTED_OS="$(detect_os)"
export DETECTED_ARCH="$(detect_arch)"
export DETECTED_CPU="$(detect_cpu)"
export DETECTED_GPU="$(detect_gpu)" 