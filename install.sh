#!/bin/bash

# Dotfiles installer wrapper
# Bootstraps minimal prerequisites and runs the profile installer.

set -e  # Exit on error

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source bootstrap utilities
source "${SCRIPT_DIR}/lib/bootstrap.sh"

PROFILE_INSTALLER="${SCRIPT_DIR}/profile-install.sh"

run_profile_installer() {
    exec "$PROFILE_INSTALLER" "$@"
}

should_skip_bootstrap() {
    if [[ $# -eq 0 ]]; then
        return 0
    fi

    local arg
    for arg in "$@"; do
        case "$arg" in
            -h|--help|-l|--list|-d|--dry-run)
                return 0
                ;;
        esac
    done

    return 1
}

echo "==================================="
echo "Dotfiles Installer"
echo "==================================="

# Check if running as root
if [ "$EUID" -eq 0 ]; then 
    echo "Error: Please run this script as a regular user (with sudo access), not as root"
    exit 1
fi

# Check if profile installer exists
if [ ! -f "$PROFILE_INSTALLER" ]; then
    echo "Error: profile-install.sh not found in $SCRIPT_DIR"
    exit 1
fi

if should_skip_bootstrap "$@"; then
    run_profile_installer "$@"
fi

bootstrap_system_prerequisites

echo ""
echo "Running profile installer..."
run_profile_installer "$@"
