#!/bin/bash

# Debian repository setup.

LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${LIB_DIR}/logging.sh"

setup_apt_keyrings_dir() {
    sudo install -m 0755 -d /etc/apt/keyrings
}

setup_docker_repo() {
    if [[ -f /etc/apt/sources.list.d/docker.list ]]; then
        log_substep "Docker repository already configured"
        return 0
    fi

    log_step "Configuring Docker repository"
    sudo apt-get install -y ca-certificates curl gnupg
    setup_apt_keyrings_dir
    curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --batch --yes --dearmor -o /etc/apt/keyrings/docker.gpg
    sudo chmod a+r /etc/apt/keyrings/docker.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
}

setup_vscode_repo() {
    sudo rm -f /etc/apt/sources.list.d/vscode.sources 2>/dev/null || true

    if [[ -f /etc/apt/sources.list.d/vscode.list ]]; then
        log_substep "VS Code repository already configured"
        return 0
    fi

    log_step "Configuring VS Code repository"
    sudo rm -f /etc/apt/sources.list.d/code.list /usr/share/keyrings/microsoft.gpg 2>/dev/null || true
    setup_apt_keyrings_dir
    curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | sudo gpg --batch --yes --dearmor -o /etc/apt/keyrings/microsoft.gpg
    echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/code stable main" | sudo tee /etc/apt/sources.list.d/vscode.list >/dev/null
}

setup_google_chrome() {
    if command -v google-chrome-stable >/dev/null 2>&1; then
        log_substep "Google Chrome already installed"
        return 0
    fi

    log_step "Installing Google Chrome"
    curl -fsSL https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb -o /tmp/chrome.deb
    sudo apt-get install -y /tmp/chrome.deb
    rm -f /tmp/chrome.deb
}

setup_tailscale_repo() {
    if [[ -f /etc/apt/sources.list.d/tailscale.list ]]; then
        log_substep "Tailscale repository already configured"
        return 0
    fi

    log_step "Configuring Tailscale repository"
    curl -fsSL "https://pkgs.tailscale.com/stable/debian/$(. /etc/os-release && echo "$VERSION_CODENAME").noarmor.gpg" | sudo tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null
    curl -fsSL "https://pkgs.tailscale.com/stable/debian/$(. /etc/os-release && echo "$VERSION_CODENAME").tailscale-keyring.list" | sudo tee /etc/apt/sources.list.d/tailscale.list >/dev/null
}

setup_virtualbox_repo() {
    if [[ -f /etc/apt/sources.list.d/virtualbox.list ]]; then
        log_substep "VirtualBox repository already configured"
        return 0
    fi

    log_step "Configuring VirtualBox repository"
    setup_apt_keyrings_dir
    curl -fsSL https://www.virtualbox.org/download/oracle_vbox_2016.asc | sudo gpg --batch --yes --dearmor -o /etc/apt/keyrings/oracle-virtualbox-2016.gpg
    echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/oracle-virtualbox-2016.gpg] https://download.virtualbox.org/virtualbox/debian $(. /etc/os-release && echo "$VERSION_CODENAME") contrib" | sudo tee /etc/apt/sources.list.d/virtualbox.list >/dev/null
}

setup_debian_flatpak() {
    if ! command -v flatpak >/dev/null 2>&1; then
        log_step "Installing flatpak"
        sudo apt-get install -y flatpak gnome-software-plugin-flatpak
    fi

    sudo flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
}

setup_debian_repositories() {
    log_header "Setting Up Debian Repositories"

    sudo apt-get update -qq
    sudo apt-get upgrade -y
    sudo dpkg --add-architecture i386

    setup_docker_repo
    setup_vscode_repo
    setup_google_chrome
    setup_tailscale_repo
    setup_virtualbox_repo
    setup_debian_flatpak

    sudo apt-get update -qq
    log_success "Debian repositories configured"
}
