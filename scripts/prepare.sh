#!/bin/bash

# Get script directory and source os-detection
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/os-detection.sh"

# brew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"


# nvm
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

nvm install 20

# pnpm
npm install -g pnpm


if is_macos; then
    echo 'include "'"$(brew --cellar nano)"'/*/share/nano/*.nanorc"' >> ~/.nanorc
fi

if is_linux; then
    sudo timedatectl set-timezone Europe/Istanbul
fi

if is_fedora; then
    
    echo "Setting up Fedora repositories..."

    # update packages
    sudo dnf update -y && sudo dnf upgrade -y

    # Enable RPM Fusion repositories
    sudo dnf install -y https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm
    sudo dnf install -y https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm

    # Enable Solopasha repositories
    sudo dnf copr enable solopasha/hyprland -y

    # Enable ghostty
    dnf copr enable pgdev/ghostty

    # Enable VSCode
    sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
    echo -e "[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\nautorefresh=1\ntype=rpm-md\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" | sudo tee /etc/yum.repos.d/vscode.repo > /dev/null

    # Enable terra
    dnf install --nogpgcheck --repofrompath 'terra,https://repos.fyralabs.com/terra$releasever' terra-release

    # update packages
    sudo dnf update -y && sudo dnf upgrade -y

    # install flatpak
    sudo dnf install -y flatpak
    # add flathub repository
    flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

    echo "Fedora repositories configured successfully!" 
fi

if is_arch; then

    # Check if yay is already installed
    if command -v yay >/dev/null 2>&1; then
        echo "yay is already installed"
        exit 0
    else
        echo "Setting up AUR helper (yay)..."
        cd /tmp
        git clone https://aur.archlinux.org/yay.git
        cd yay
        makepkg -si --noconfirm
        cd ..
        rm -rf yay
    fi

    # enable parallel downloads for pacman
    sudo sed -i 's/^#ParallelDownloads/ParallelDownloads/' /etc/pacman.conf

    # update packages
    sudo pacman -Syu --noconfirm
    yay -Syu --noconfirm

    # install flatpak
    sudo pacman -S --noconfirm flatpak
    # add flathub repository
    flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

    echo "Arch repositories configured successfully!" 
fi

