#!/bin/bash

# Bootstrap script for dotfiles installation
# This is the main entry point that detects OS and runs appropriate installer

set -e

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Source utilities
source "${DOTFILES_DIR}/lib/logging.sh"
source "${DOTFILES_DIR}/lib/os-detection.sh"

# Main function
main() {
    log_header "Dotfiles Bootstrap"
    
    log_info "Detected OS: $DETECTED_OS"
    log_info "Detected Architecture: $DETECTED_ARCH"
    log_info "Dotfiles Directory: $DOTFILES_DIR"
    
    # Check if we're in the right directory
    if [[ ! -f "${DOTFILES_DIR}/install/bootstrap.sh" ]]; then
        log_error "Cannot find bootstrap script. Are you running from the correct directory?"
        exit 1
    fi
    
    # Run OS-specific installer
    case "$DETECTED_OS" in
        macos)
            log_step "Running macOS installer..."
            bash "${SCRIPT_DIR}/macos.sh"
            ;;
        arch)
            log_step "Running Arch Linux installer..."
            bash "${SCRIPT_DIR}/arch.sh"
            ;;
        fedora)
            log_step "Running Fedora installer..."
            bash "${SCRIPT_DIR}/fedora.sh"
            ;;
        ubuntu)
            log_warning "Ubuntu support is not yet implemented"
            log_info "You can manually install packages and run the symlink script"
            ;;
        *)
            log_error "Unsupported operating system: $DETECTED_OS"
            log_info "Supported systems: macOS, Arch Linux, Fedora"
            exit 1
            ;;
    esac
    
    log_success "Bootstrap completed!"
    log_info "You may need to restart your shell or run 'source ~/.zshrc'"
}

# Show help
show_help() {
    echo "Dotfiles Bootstrap Script"
    echo ""
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  -h, --help     Show this help message"
    echo "  -d, --debug    Enable debug output"
    echo ""
    echo "Supported Systems:"
    echo "  - macOS (with Homebrew)"
    echo "  - Arch Linux (with pacman/yay)"
    echo "  - Fedora (with dnf)"
    echo ""
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -d|--debug)
            export DEBUG=1
            shift
            ;;
        *)
            log_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Run main function
main "$@" 