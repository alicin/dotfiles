#!/bin/bash

# Profile-based dotfiles installer
# Usage: ./profile-install.sh [profile] [options]

set -e

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROFILES_DIR="${SCRIPT_DIR}/profiles"

# Source utilities
source "${SCRIPT_DIR}/lib/logging.sh"
source "${SCRIPT_DIR}/lib/os-detection.sh"
source "${SCRIPT_DIR}/lib/symlink.sh"
source "${SCRIPT_DIR}/lib/profile.sh"

# Show help
show_help() {
    echo "Profile-based Dotfiles Installer"
    echo ""
    echo "Usage: $0 [profile] [options]"
    echo ""
    echo "Available Profiles:"
    list_available_profiles "$PROFILES_DIR"
    echo ""
    echo "Options:"
    echo "  -h, --help           Show this help"
    echo "  -l, --list          List available profiles"
    echo "  -a, --auto          Auto-detect profile based on hostname"
    echo "  -d, --dry-run       Show what would be installed without installing"
    echo "  -p, --packages-only Install packages only"
    echo "  -c, --configs-only  Link configurations only"
    echo "  -s, --scripts-only  Run scripts only"
    echo "  -f, --force         Force installation without prompts"
    echo "  -v, --verbose       Verbose output"
    echo ""
    echo "Examples:"
    echo "  $0 discobot-darwin      # Install discobot-darwin profile"
    echo "  $0 --auto           # Auto-detect and install profile"
    echo "  $0 mcu-arch --dry-run # Show what mcu-arch would install"
    echo ""
}

# Install packages for profile
install_profile_packages() {
    local profile_dir="$1"
    
    log_header "Installing Packages"
    
    # Install packages based on enabled package managers
    case "$DETECTED_OS" in
        macos)
            if is_package_manager_enabled "homebrew"; then
                local brewfile="$profile_dir/packages/$(get_package_manager_file "homebrew")"
                if [[ -f "$brewfile" ]]; then
                    log_step "Installing packages via Homebrew (skipping already installed)"
                    brew bundle install --file="$brewfile"
                else
                    log_warning "Brewfile not found: $brewfile"
                fi
            fi
            ;;
        arch)
            if is_package_manager_enabled "pacman"; then
                local pacman_file="$profile_dir/packages/$(get_package_manager_file "pacman")"
                if [[ -f "$pacman_file" ]]; then
                    log_step "Installing packages via pacman (skipping already installed)"
                    sudo pacman -S --needed --noconfirm $(cat "$pacman_file")
                else
                    log_warning "Pacman package file not found: $pacman_file"
                fi
            fi
            
            if is_package_manager_enabled "yay"; then
                local aur_file="$profile_dir/packages/$(get_package_manager_file "yay")"
                if [[ -f "$aur_file" ]]; then
                    if command -v yay >/dev/null 2>&1; then
                        log_step "Installing AUR packages via yay (skipping already installed)"
                        yay -S --needed --noconfirm $(cat "$aur_file")
                    else
                        log_warning "yay not found, skipping AUR packages"
                    fi
                else
                    log_warning "AUR package file not found: $aur_file"
                fi
            fi

            if is_package_manager_enabled "homebrew"; then
                local brewfile="$profile_dir/packages/$(get_package_manager_file "homebrew")"
                if [[ -f "$brewfile" ]]; then
                    log_step "Installing packages via Homebrew (skipping already installed)"
                    brew bundle install --file="$brewfile"
                else
                    log_warning "Brewfile not found: $brewfile"
                fi
            fi

            ;;
        fedora)
            if is_package_manager_enabled "dnf"; then
                local dnf_file="$profile_dir/packages/$(get_package_manager_file "dnf")"
                if [[ -f "$dnf_file" ]]; then
                    log_step "Installing packages via dnf (skipping already installed)"
                    
                    # Read packages and filter out already installed ones
                    local packages_to_install=()
                    while IFS= read -r package; do
                        [[ -z "$package" || "$package" =~ ^# ]] && continue
                        if ! rpm -q "$package" >/dev/null 2>&1; then
                            packages_to_install+=("$package")
                        else
                            log_substep "Skipping already installed: $package"
                        fi
                    done < "$dnf_file"
                    
                    # Install only the packages that aren't already installed
                    if [[ ${#packages_to_install[@]} -gt 0 ]]; then
                        sudo dnf install -y --skip-unavailable --skip-broken --allowerasing "${packages_to_install[@]}"
                    else
                        log_substep "All packages already installed"
                    fi
                else
                    log_warning "DNF package file not found: $dnf_file"
                fi
            fi
            
            if is_package_manager_enabled "flatpak"; then
                local flatpak_file="$profile_dir/packages/$(get_package_manager_file "flatpak")"
                if [[ -f "$flatpak_file" ]]; then
                    log_step "Installing Flatpak applications (skipping already installed)"
                    flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
                    while IFS= read -r app; do
                        [[ -z "$app" || "$app" =~ ^# ]] && continue
                        if ! flatpak list | grep -q "$app"; then
                            flatpak install -y flathub "$app"
                        else
                            log_substep "Skipping already installed: $app"
                        fi
                    done < "$flatpak_file"
                else
                    log_warning "Flatpak package file not found: $flatpak_file"
                fi
            fi
            ;;
        windows)
            if is_package_manager_enabled "winget"; then
                local winget_file="$profile_dir/packages/$(get_package_manager_file "winget")"
                if [[ -f "$winget_file" ]]; then
                    log_step "Installing packages via winget (skipping already installed)"
                    while IFS= read -r package; do
                        [[ -z "$package" || "$package" =~ ^# ]] && continue
                        if ! winget list --id "$package" >/dev/null 2>&1; then
                            winget install --id "$package" --silent --accept-source-agreements --accept-package-agreements
                        else
                            log_substep "Skipping already installed: $package"
                        fi
                    done < "$winget_file"
                else
                    log_warning "Winget package file not found: $winget_file"
                fi
            fi
            
            if is_package_manager_enabled "scoop"; then
                local scoop_file="$profile_dir/packages/$(get_package_manager_file "scoop")"
                if [[ -f "$scoop_file" ]]; then
                    log_step "Installing packages via scoop (skipping already installed)"
                    
                    # Read packages and filter out already installed ones
                    local packages_to_install=()
                    while IFS= read -r package; do
                        [[ -z "$package" || "$package" =~ ^# ]] && continue
                        if ! scoop list "$package" >/dev/null 2>&1; then
                            packages_to_install+=("$package")
                        else
                            log_substep "Skipping already installed: $package"
                        fi
                    done < "$scoop_file"
                    
                    # Install only the packages that aren't already installed
                    if [[ ${#packages_to_install[@]} -gt 0 ]]; then
                        scoop install "${packages_to_install[@]}"
                    else
                        log_substep "All packages already installed"
                    fi
                else
                    log_warning "Scoop package file not found: $scoop_file"
                fi
            fi
            ;;
        *)
            log_warning "Package installation not implemented for $DETECTED_OS"
            ;;
    esac
}

# Link configurations for profile
link_profile_configs() {
    local profile_dir="$1"
    
    log_header "Linking Configurations"
    
    # Link dotfiles
    log_step "Linking dotfiles"
    get_profile_array "dotfiles" | while IFS= read -r dotfile; do
        [[ -n "$dotfile" ]] && link_dotfile "$dotfile"
    done
    
    # Link config directories
    log_step "Linking config directories"
    get_profile_array "configs" | while IFS= read -r config; do
        [[ -n "$config" ]] && link_config "$config"
    done
    
    # Link themes
    log_step "Linking themes"
    get_profile_array "themes" | while IFS= read -r theme; do
        [[ -n "$theme" ]] && link_theme "$theme"
    done
}

# Run profile scripts
run_profile_scripts() {
    local profile_dir="$1"
    local script_type="$2"  # pre_install or post_install
    
    log_header "Running $script_type Scripts"
    
    get_profile_array "scripts.$script_type" | while IFS= read -r script; do
        if [[ -n "$script" ]]; then
            local script_path="${SCRIPT_DIR}/scripts/$script"
            if [[ -f "$script_path" ]]; then
                log_step "Running script: $script"
                if [[ "$script" =~ \.ps1$ ]]; then
                    # PowerShell script (Windows)
                    powershell -ExecutionPolicy Bypass -File "$script_path"
                else
                    # Bash script
                    chmod +x "$script_path"
                    "$script_path"
                fi
            else
                log_warning "Script not found: $script_path"
            fi
        fi
    done
}

# Show what would be installed
dry_run() {
    local profile_dir="$1"
    
    log_header "Dry Run"
    log_info "Profile: $(get_profile_field "name")"
    log_info "Description: $(get_profile_field "description")"
    log_info "Hostname: $(get_profile_field "hostname")"
    log_info "OS: $(get_profile_field "os") ($(get_profile_field "arch"))"
    
    echo ""
    echo "📦 Package managers that would be used:"
    jq -r '.package_managers | to_entries[] | select(.value.enabled == true) | "   \(.key): \(.value.file)"' "$PROFILE_JSON"
    
    echo ""
    echo "🔗 Configurations that would be linked:"
    get_profile_array "configs" | while IFS= read -r config; do
        [[ -n "$config" ]] && echo "   ~/.config/$config"
    done
    
    echo ""
    echo "📁 Dotfiles that would be linked:"
    get_profile_array "dotfiles" | while IFS= read -r dotfile; do
        [[ -n "$dotfile" ]] && echo "   ~/.$dotfile"
    done
    
    echo ""
    echo "🎨 Themes that would be linked:"
    get_profile_array "themes" | while IFS= read -r theme; do
        [[ -n "$theme" ]] && echo "   ~/.$theme"
    done
    
    if get_profile_array "scripts.pre_install" | grep -q .; then
        echo ""
        echo "🔧 Pre-install scripts that would run:"
        get_profile_array "scripts.pre_install" | while IFS= read -r script; do
            [[ -n "$script" ]] && echo "   $script"
        done
    fi
    
    if get_profile_array "scripts.post_install" | grep -q .; then
        echo ""
        echo "🔧 Post-install scripts that would run:"
        get_profile_array "scripts.post_install" | while IFS= read -r script; do
            [[ -n "$script" ]] && echo "   $script"
        done
    fi
    
    echo ""
    echo "Use --force to proceed with installation"
}

# Main installation function
install_profile() {
    local profile_name="$1"
    local packages_only="$2"
    local configs_only="$3"
    local scripts_only="$4"
    
    local profile_dir=$(get_profile_dir "$PROFILES_DIR" "$profile_name")
    
    log_header "Installing Profile: $profile_name"
    log_info "Profile: $(get_profile_field "name")"
    log_info "Description: $(get_profile_field "description")"
    log_info "OS: $DETECTED_OS ($DETECTED_ARCH)"
    
    # Set environment variables from profile
    log_step "Setting environment variables"
    get_profile_field "environment" | jq -r 'to_entries[]? | "export \(.key)=\(.value)"' | while IFS= read -r env_var; do
        [[ -n "$env_var" ]] && eval "$env_var"
    done

    # Link configurations
    if [[ "$packages_only" != "true" && "$scripts_only" != "true" ]]; then
        link_profile_configs "$profile_dir"
    fi
    
    # Run pre-install scripts
    if [[ "$packages_only" != "true" && "$configs_only" != "true" ]]; then
        run_profile_scripts "$profile_dir" "pre_install"
    fi
    
    # Install packages
    if [[ "$configs_only" != "true" && "$scripts_only" != "true" ]]; then
        install_profile_packages "$profile_dir"
    fi
    
    # Run post-install scripts
    if [[ "$packages_only" != "true" && "$configs_only" != "true" ]]; then
        run_profile_scripts "$profile_dir" "post_install"
    fi
    
    log_success "Profile $profile_name installed successfully!"
    echo ""
    echo "Next steps:"
    echo "  1. Restart your shell or run: source ~/.zshrc"
    echo "  2. Verify hostname matches profile: $(get_profile_field "hostname")"
    echo "  3. Check profile-specific configurations in ~/.config/"
}

# Parse command line arguments
PROFILE=""
AUTO_DETECT=false
DRY_RUN=false
PACKAGES_ONLY=false
CONFIGS_ONLY=false
SCRIPTS_ONLY=false
FORCE=false
VERBOSE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -l|--list)
            echo "Available Profiles:"
            echo ""
            list_available_profiles "$PROFILES_DIR"
            exit 0
            ;;
        -a|--auto)
            AUTO_DETECT=true
            shift
            ;;
        -d|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -p|--packages-only)
            PACKAGES_ONLY=true
            shift
            ;;
        -c|--configs-only)
            CONFIGS_ONLY=true
            shift
            ;;
        -s|--scripts-only)
            SCRIPTS_ONLY=true
            shift
            ;;
        -f|--force)
            FORCE=true
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            export DEBUG=1
            shift
            ;;
        -*)
            log_error "Unknown option: $1"
            show_help
            exit 1
            ;;
        *)
            if [[ -z "$PROFILE" ]]; then
                PROFILE="$1"
            else
                log_error "Multiple profiles specified: $PROFILE and $1"
                exit 1
            fi
            shift
            ;;
    esac
done

# Auto-detect profile if requested
if [[ "$AUTO_DETECT" == "true" ]]; then
    if [[ -n "$PROFILE" ]]; then
        log_error "Cannot specify both --auto and a profile name"
        exit 1
    fi
    
    PROFILE=$(auto_detect_profile "$PROFILES_DIR")
    if [[ $? -ne 0 ]]; then
        echo ""
        echo "Available profiles:"
        list_available_profiles "$PROFILES_DIR"
        exit 1
    fi
fi

# Show help if no profile specified
if [[ -z "$PROFILE" ]]; then
    show_help
    exit 0
fi

# Validate and load the profile
if ! validate_profile "$PROFILES_DIR" "$PROFILE"; then
    exit 1
fi

# Run dry run if requested
if [[ "$DRY_RUN" == "true" ]]; then
    dry_run $(get_profile_dir "$PROFILES_DIR" "$PROFILE")
    exit 0
fi

# Confirm installation unless force flag is used
if [[ "$FORCE" != "true" ]]; then
    echo ""
    log_info "About to install profile: $PROFILE"
    log_info "Description: $(get_profile_field "description")"
    echo ""
    read -p "Continue with installation? [y/N] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Installation cancelled"
        exit 0
    fi
fi

# Run the installation
install_profile "$PROFILE" "$PACKAGES_ONLY" "$CONFIGS_ONLY" "$SCRIPTS_ONLY" 
