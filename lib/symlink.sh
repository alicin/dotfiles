#!/bin/bash

# Symlink management utilities
# Usage: source this file and use the symlink functions

# Source logging
LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${LIB_DIR}/logging.sh"

# Get the dotfiles directory (assumes this script is in dotfiles/lib/)
DOTFILES_DIR="$(cd "${LIB_DIR}/.." && pwd)"

# Create a symlink with backup if target exists
create_symlink() {
    local source="$1"
    local target="$2"
    local backup_dir="${HOME}/.dotfiles-backup/$(date +%Y%m%d_%H%M%S)"

    # Check if source exists
    if [[ ! -e "$source" ]]; then
        log_error "Source file does not exist: $source"
        return 1
    fi

    # Create target directory if it doesn't exist
    local target_dir="$(dirname "$target")"
    if [[ ! -d "$target_dir" ]]; then
        log_substep "Creating directory: $target_dir"
        mkdir -p "$target_dir"
    fi

    # Handle existing target
    if [[ -e "$target" ]] || [[ -L "$target" ]]; then
        if [[ -L "$target" ]] && [[ "$(readlink "$target")" == "$source" ]]; then
            log_substep "Symlink already exists and is correct: $target"
            return 0
        fi
        
        log_substep "Backing up existing file: $target"
        mkdir -p "$backup_dir"
        mv "$target" "$backup_dir/"
    fi

    # Create the symlink
    log_substep "Creating symlink: $target -> $source"
    ln -s "$source" "$target"
    
    if [[ $? -eq 0 ]]; then
        return 0
    else
        log_error "Failed to create symlink: $target -> $source"
        return 1
    fi
}

# Link config directory
link_config() {
    local config_name="$1"
    local source="${DOTFILES_DIR}/config/${config_name}"
    local target="${HOME}/.config/${config_name}"
    
    log_step "Linking config: $config_name"
    create_symlink "$source" "$target"
}

# Link dotfile
link_dotfile() {
    local dotfile_name="$1"
    local source="${DOTFILES_DIR}/dotfiles/${dotfile_name}"
    local target="${HOME}/${dotfile_name}"
    
    log_step "Linking dotfile: $dotfile_name"
    create_symlink "$source" "$target"
}

# Link theme directory
link_theme() {
    local theme_name="$1"
    local source="${DOTFILES_DIR}/themes/${theme_name}"
    local target="${HOME}/.${theme_name}"
    
    log_step "Linking theme: $theme_name"
    create_symlink "$source" "$target"
}

# Remove broken symlinks
cleanup_broken_symlinks() {
    log_step "Cleaning up broken symlinks in $HOME"
    find "$HOME" -maxdepth 3 -type l ! -exec test -e {} \; -exec rm {} \; 2>/dev/null
}

# Verify symlinks
verify_symlinks() {
    local failed=0
    
    log_step "Verifying symlinks..."
    
    # Check common dotfiles
    local dotfiles=("zshrc" "gitconfig" "editorconfig" "p10k.zsh")
    for dotfile in "${dotfiles[@]}"; do
        local target="${HOME}/.${dotfile}"
        if [[ -L "$target" ]]; then
            if [[ -e "$target" ]]; then
                log_substep "✓ $dotfile"
            else
                log_substep "✗ $dotfile (broken link)"
                ((failed++))
            fi
        else
            log_substep "? $dotfile (not linked)"
        fi
    done
    
    return $failed
} 