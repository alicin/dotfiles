#!/bin/bash

# Fedora repository setup.

LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${LIB_DIR}/logging.sh"

setup_fedora_rpmfusion() {
    if rpm -q rpmfusion-free-release rpmfusion-nonfree-release >/dev/null 2>&1; then
        log_substep "RPM Fusion already configured"
        return 0
    fi

    log_step "Configuring RPM Fusion"
    sudo dnf install -y "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm"
    sudo dnf install -y "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm"
}

setup_fedora_copr() {
    local repo="$1"
    local repo_file="/etc/yum.repos.d/_copr:copr.fedorainfracloud.org:${repo//\//:}.repo"

    if [[ -f "$repo_file" ]]; then
        log_substep "COPR already configured: $repo"
        return 0
    fi

    log_step "Enabling COPR: $repo"
    sudo dnf copr enable "$repo" -y
}

setup_fedora_vscode_repo() {
    if [[ -f /etc/yum.repos.d/vscode.repo ]]; then
        log_substep "VS Code repository already configured"
        return 0
    fi

    log_step "Configuring VS Code repository"
    sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
    printf '%s\n' \
        '[code]' \
        'name=Visual Studio Code' \
        'baseurl=https://packages.microsoft.com/yumrepos/vscode' \
        'enabled=1' \
        'autorefresh=1' \
        'type=rpm-md' \
        'gpgcheck=1' \
        'gpgkey=https://packages.microsoft.com/keys/microsoft.asc' | sudo tee /etc/yum.repos.d/vscode.repo >/dev/null
}

setup_fedora_flatpak() {
    if ! command -v flatpak >/dev/null 2>&1; then
        log_step "Installing flatpak"
        sudo dnf install -y flatpak
    fi

    flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
}

setup_fedora_repositories() {
    log_header "Setting Up Fedora Repositories"

    sudo dnf update -y
    setup_fedora_rpmfusion
    setup_fedora_copr solopasha/hyprland
    setup_fedora_copr atim/starship
    setup_fedora_copr lihaohong/yazi
    setup_fedora_copr pgdev/ghostty
    setup_fedora_copr zeno/scrcpy
    setup_fedora_vscode_repo
    sudo dnf config-manager setopt fedora-cisco-openh264.enabled=1
    sudo dnf update -y
    setup_fedora_flatpak

    log_success "Fedora repositories configured"
}
