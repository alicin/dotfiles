#!/bin/bash

# Source OS detection utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/os-detection.sh"

if is_macos; then
    rm -rf '/Users/ali/Library/Application Support/com.mitchellh.ghostty/config'
fi

if is_linux; then

    # greetd + Hyprland setup (Arch/Fedora only — Debian uses GNOME + GDM)
    if is_arch || is_fedora; then
        echo "Setting up greetd..."
        sudo systemctl disable sddm 2>/dev/null || true
        sudo systemctl disable gdm 2>/dev/null || true
        sudo systemctl enable greetd
        sudo mkdir -p /usr/lib/systemd/system/greetd.service.d/
        sudo cp "${SCRIPT_DIR}/../system/etc/00-nobleed.conf" /usr/lib/systemd/system/greetd.service.d/00-nobleed.conf
        sudo sed -i 's/command = "agreety --cmd \/bin\/sh"/command = "tuigreet -r --remember-session --asterisks --cmd Hyprland"/' /etc/greetd/config.toml
    fi

    echo "Setting up groups..."
    for group in libvirt kvm docker input wheel vboxusers; do
        if getent group "$group" >/dev/null 2>&1; then
            sudo usermod -aG "$group" "$(whoami)"
        fi
    done
    # Arch-specific groups
    if is_arch; then
        for group in openrazer; do
            if getent group "$group" >/dev/null 2>&1; then
                sudo usermod -aG "$group" "$(whoami)"
            fi
        done
    fi

    echo "Setting up QEMU/Libvirt..."
    if [[ -f /etc/libvirt/qemu.conf ]]; then
        sudo sed -i 's/^#user = .*/user = "root"/' /etc/libvirt/qemu.conf
        sudo sed -i 's/^#group = .*/group = "root"/' /etc/libvirt/qemu.conf
        sudo virsh net-autostart default 2>/dev/null || true
    fi

    echo "Setting up samba..."
    if [[ -f "${SCRIPT_DIR}/../system/etc/smb.conf" ]] && command -v smbd >/dev/null 2>&1; then
        sudo cp "${SCRIPT_DIR}/../system/etc/smb.conf" /etc/samba/smb.conf
        if is_arch; then
            sudo systemctl restart smb.service
            sudo systemctl restart nmb.service
        fi
        if is_debian; then
            sudo systemctl restart smbd.service 2>/dev/null || true
            sudo systemctl restart nmbd.service 2>/dev/null || true
        fi
    fi

    if is_amd_cpu; then

        echo "Setting up corectrl..."
        sudo cp "${SCRIPT_DIR}/../system/etc/90-corectrl.rules" /etc/polkit-1/rules.d/90-corectrl.rules
        echo "Setting up ryzen smu..."
        sudo cp "${SCRIPT_DIR}/../system/etc/ryzen_smu.conf" /etc/modules-load.d/ryzen_smu.conf

    fi
    
    if is_arm; then

        echo "Setting up keyboard..."
        touch hid_apple.conf
        echo "options hid_apple fnmode=2" > hid_apple.conf
        sudo mv hid_apple.conf /etc/modprobe.d/hid_apple.conf
        
        echo "Setting up GRUB for notch display..."
        sudo sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="\(.*\)"/GRUB_CMDLINE_LINUX_DEFAULT="\1 apple_dcp.show_notch=1"/' /etc/default/grub
        sudo grub2-mkconfig -o /boot/grub2/grub.cfg
        
        echo "Setting up waydroid..."
        # sudo waydroid init -s GAPPS -f -c https://ota.waydro.id/system -v https://ota.waydro.id/vendor
        
        echo "Setting up widevine..."
        sudo widevine-install 

        echo "Regenerating initramfs..."
        sudo dracut --regenerate-all --force 

        echo "Remove fedora shenannigans for firefox..."
        sudo rm -f /usr/lib64/firefox/browser/defaults/preferences/firefox-redhat-default-prefs.js


    fi

    echo "Setting up flatpak..."
    if command -v flatpak >/dev/null 2>&1 && [[ -d "${HOME}/.var/app" ]] && ls "${HOME}/.var/app/"* >/dev/null 2>&1; then
        source "${SCRIPT_DIR}/../bin/flatfix" || true
    fi

    echo "Setting up zsh..."
    sudo chsh -s /usr/bin/zsh "$(whoami)"
fi

echo "Setting up oh-my-zsh..."
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended

echo "Setting up oh-my-zsh plugins..."
git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions 2>/dev/null || true
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting 2>/dev/null || true
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k 2>/dev/null || true
if [[ -f ~/.zshrc.pre-oh-my-zsh ]]; then
    rm -f ~/.zshrc
    mv ~/.zshrc.pre-oh-my-zsh ~/.zshrc
fi


