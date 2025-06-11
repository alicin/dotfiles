#!/bin/bash

# Source OS detection utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/os-detection.sh"

if is_macos; then
    rm -rf '/Users/ali/Library/Application Support/com.mitchellh.ghostty/config'
fi

if is_linux; then

    echo "Setting up greetd..."
    # disable sddm and gdm
    sudo systemctl disable sddm
    sudo systemctl disable gdm
    # enable greetd
    sudo systemctl enable greetd
    # create greetd service directory
    sudo mkdir /usr/lib/systemd/system/greetd.service.d/
    # copy greetd service file
    sudo cp "${SCRIPT_DIR}/../system/etc/00-nobleed.conf" /usr/lib/systemd/system/greetd.service.d/00-nobleed.conf
    # configure greetd to use tuigreet with Hyprland
    sudo sed -i 's/command = "agreety --cmd \/bin\/sh"/command = "tuigreet -r --remember-session --asterisks --cmd Hyprland"/' /etc/greetd/config.toml

    echo "Setting up groups..."
    sudo usermod -aG kvm $(whoami)
    sudo usermod -aG libvirt $(whoami)
    sudo usermod -aG input $(whoami)

    echo "Setting up QEMU/Libvirt..."
    sudo sed -i 's/^#user = .*/user = "root"/' /etc/libvirt/qemu.conf
    sudo sed -i 's/^#group = .*/group = "root"/' /etc/libvirt/qemu.conf
    sudo virsh net-autostart default

    
    if is_arch; then

        echo "Setting up samba..."
        sudo cp "${SCRIPT_DIR}/../system/etc/smb.conf" /etc/samba/smb.conf
        sudo systemctl restart smb.service
        sudo systemctl restart nmb.service
        
    fi

    if ! is_arm; then

        echo "Setting up corectrl..."
        sudo cp "${SCRIPT_DIR}/../system/etc/90-corectrl.rules" /etc/polkit-1/rules.d/90-corectrl.rules
        echo "Setting up ryzen smu..."
        sudo cp "${SCRIPT_DIR}/../system/etc/ryzen_smu.conf" /etc/modules-load.d/ryzen_smu.conf

        echo "Setting up waydroid..."
        sudo waydroid init -s GAPPS -f

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
    source "${SCRIPT_DIR}/../bin/flatfix"

    echo "Setting up zsh..."
    chsh -s /usr/bin/zsh
    /usr/bin/zsh

fi

echo "Setting up oh-my-zsh..."
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

echo "Setting up oh-my-zsh plugins..."
git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k
rm ~/.zshrc && mv ~/.zshrc.pre-oh-my-zsh ~/.zshrc


