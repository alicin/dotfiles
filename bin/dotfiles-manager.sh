#!/bin/bash

# Dotfiles management utility
# Provides tools for maintaining and updating the dotfiles repository

set -e

# Source utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
source "${DOTFILES_DIR}/lib/logging.sh"
source "${DOTFILES_DIR}/lib/os-detection.sh"
source "${DOTFILES_DIR}/lib/symlink.sh"

# Configuration
BACKUP_DIR="${HOME}/.dotfiles-backups"
CONFIG_DIR="${HOME}/.config"

# Create backup of current dotfiles
backup_dotfiles() {
    local backup_name="backup_$(date +%Y%m%d_%H%M%S)"
    local backup_path="${BACKUP_DIR}/${backup_name}"
    
    log_header "Creating Dotfiles Backup"
    log_info "Backup location: $backup_path"
    
    mkdir -p "$backup_path"
    
    # Backup traditional dotfiles
    local dotfiles=(".zshrc" ".gitconfig" ".editorconfig" ".p10k.zsh")
    for dotfile in "${dotfiles[@]}"; do
        if [[ -e "${HOME}/${dotfile}" ]]; then
            log_substep "Backing up $dotfile"
            cp -r "${HOME}/${dotfile}" "${backup_path}/"
        fi
    done
    
    # Backup config directories
    if [[ -d "$CONFIG_DIR" ]]; then
        log_substep "Backing up .config directory"
        cp -r "$CONFIG_DIR" "${backup_path}/"
    fi
    
    log_success "Backup created: $backup_path"
    echo "$backup_path"
}

# Restore from backup
restore_backup() {
    local backup_name="$1"
    
    if [[ -z "$backup_name" ]]; then
        log_error "Please specify backup name"
        list_backups
        exit 1
    fi
    
    local backup_path="${BACKUP_DIR}/${backup_name}"
    
    if [[ ! -d "$backup_path" ]]; then
        log_error "Backup not found: $backup_path"
        list_backups
        exit 1
    fi
    
    log_header "Restoring from Backup"
    log_info "Restoring from: $backup_path"
    
    # Restore traditional dotfiles
    for file in "$backup_path"/.*; do
        if [[ -f "$file" && ! "$(basename "$file")" =~ ^\.(\.)?$ ]]; then
            local filename="$(basename "$file")"
            log_substep "Restoring $filename"
            cp "$file" "${HOME}/"
        fi
    done
    
    # Restore config directory
    if [[ -d "${backup_path}/.config" ]]; then
        log_substep "Restoring .config directory"
        cp -r "${backup_path}/.config"/* "${HOME}/.config/"
    fi
    
    log_success "Backup restored successfully"
}

# List available backups
list_backups() {
    log_header "Available Backups"
    
    if [[ ! -d "$BACKUP_DIR" ]] || [[ -z "$(ls -A "$BACKUP_DIR" 2>/dev/null)" ]]; then
        log_info "No backups found"
        return
    fi
    
    for backup in "$BACKUP_DIR"/*; do
        if [[ -d "$backup" ]]; then
            local backup_name="$(basename "$backup")"
            local backup_size="$(du -sh "$backup" | cut -f1)"
            local backup_date="$(stat -c %y "$backup" 2>/dev/null || stat -f %Sm "$backup" 2>/dev/null)"
            
            echo "📁 $backup_name"
            echo "   Size: $backup_size"
            echo "   Date: $backup_date"
            echo ""
        fi
    done
}

# Update dotfiles repository
update_repository() {
    log_header "Updating Dotfiles Repository"
    
    cd "$DOTFILES_DIR"
    
    # Check if we're in a git repository
    if [[ ! -d ".git" ]]; then
        log_warning "Not a git repository. Skipping git operations."
        return
    fi
    
    # Check for uncommitted changes
    if ! git diff-index --quiet HEAD --; then
        log_warning "Uncommitted changes detected:"
        git status --porcelain
        echo ""
        read -p "Continue anyway? [y/N] " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Update cancelled"
            return
        fi
    fi
    
    # Pull latest changes
    log_step "Pulling latest changes..."
    git pull origin main || git pull origin master || {
        log_error "Failed to pull changes"
        return 1
    }
    
    log_success "Repository updated successfully"
    
    # Ask if user wants to reinstall
    echo ""
    read -p "Reinstall dotfiles with current profile? [y/N] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log_info "Please run: ./install.sh [profile] to reinstall"
    fi
}

# Clean up broken symlinks
cleanup_symlinks() {
    log_header "Cleaning Up Broken Symlinks"
    
    cleanup_broken_symlinks
    
    log_success "Cleanup completed"
}

# Verify installation
verify_installation() {
    log_header "Verifying Dotfiles Installation"
    
    verify_symlinks
    
    # Additional checks
    log_step "Checking shell configuration..."
    if [[ "$SHELL" == *"zsh"* ]]; then
        log_substep "✓ Using zsh shell"
    else
        log_substep "! Not using zsh shell"
        log_info "Current shell: $SHELL"
    fi
    
    # Check oh-my-zsh
    if [[ -d "${HOME}/.oh-my-zsh" ]]; then
        log_substep "✓ oh-my-zsh installed"
    else
        log_substep "! oh-my-zsh not found"
    fi
    
    log_success "Verification completed"
}

# Export current configuration
export_config() {
    local export_dir="$1"
    
    if [[ -z "$export_dir" ]]; then
        export_dir="${HOME}/dotfiles-export-$(date +%Y%m%d_%H%M%S)"
    fi
    
    log_header "Exporting Configuration"
    log_info "Export directory: $export_dir"
    
    mkdir -p "$export_dir"
    
    # Copy dotfiles
    cp -r "$DOTFILES_DIR" "$export_dir/"
    
    # Create a simple installer
    cat > "${export_dir}/quick-install.sh" << 'EOF'
#!/bin/bash
# Quick installer for exported dotfiles
cd "$(dirname "$0")/dotfiles"
chmod +x install.sh
./install.sh minimal
EOF
    
    chmod +x "${export_dir}/quick-install.sh"
    
    log_success "Configuration exported to: $export_dir"
}

# Show help
show_help() {
    echo "Dotfiles Manager"
    echo ""
    echo "Usage: $0 <command> [options]"
    echo ""
    echo "Commands:"
    echo "  backup                Create backup of current dotfiles"
    echo "  restore <name>        Restore from backup"
    echo "  list-backups          List available backups"
    echo "  update                Update dotfiles repository"
    echo "  cleanup               Clean up broken symlinks"
    echo "  verify                Verify installation"
    echo "  export [dir]          Export configuration"
    echo ""
    echo "Examples:"
    echo "  $0 backup             # Create backup"
    echo "  $0 restore backup_20240101_120000"
    echo "  $0 update             # Update from git"
    echo "  $0 verify             # Check installation"
    echo ""
}

# Parse command
case "${1:-}" in
    backup)
        backup_dotfiles
        ;;
    restore)
        restore_backup "$2"
        ;;
    list-backups|list)
        list_backups
        ;;
    update)
        update_repository
        ;;
    cleanup)
        cleanup_symlinks
        ;;
    verify)
        verify_installation
        ;;
    export)
        export_config "$2"
        ;;
    -h|--help|"")
        show_help
        exit 0
        ;;
    *)
        log_error "Unknown command: $1"
        show_help
        exit 1
        ;;
esac 