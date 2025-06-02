# permission
echo "SET PERMISSIONS"
chmod 400 ~/.ssh/id_rsa
chmod 644 ~/.ssh/config
chmod +x ~/labs/dotfiles/bin/*

mkdir ~/.local/bin

sudo visudo

# Enable Parallel Downloads
sudo nano /etc/pacman.conf

# yay
git clone https://aur.archlinux.org/yay.git
cd yay
makepkg -si
cd ../
rm -rf yay

yay -Syu --noconfirm - < pkglist.txt

# Brew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
brew bundle install --file Brewfile

# finger print
fprintd-enroll
sudo nano /etc/pam.d/system-local-login
# add belowto the top
# auth sufficient pam_fprintd.so

# pyvenv
python -m venv ~/.venv
source ~/.venv/bin/activate

# richweather
git clone https://github.com/Rizen54/richweather
cd richweather
~/.venv/bin/pip install .
mkdir ~/.config/richweather/
cp richweather.yaml ~/.config/richweather/
mv ~/.venv/bin/richweather ~/.local/bin/
cd ../
rm -rf richweather

# Waydroid
sudo waydroid init -s GAPPS

# bottles
flatpak install flathub com.usebottles.bottles

# Services
sudo systemctl enable --now cronie
sudo systemctl enable --now systemd-timesyncd.service
sudo systemctl enable avahi-dnsconfd.service --now
sudo systemctl enable avahi-dnsconfd.service --nowd
sudo systemctl enable sshd --now
sudo systemctl enable paccache.timer --now
sudo systemctl enable fstrim.timer --now
sudo systemctl enable bluetooth --now
sudo systemctl enable libvirtd --now

DOTFILESSRC=/home/ali/labs/dotfiles
alias rm=rm

# tui greet
sudo systemctl disable sddm
sudo systemctl enable greetd
sudo mkdir /usr/lib/systemd/system/greetd.service.d/
sudo cp ${DOTFILESSRC}/etc/00-nobleed.conf /usr/lib/systemd/system/greetd.service.d/00-nobleed.conf
sudo nano /etc/greetd/config.toml
# tuigreet -r --remember-session --asterisks --cmd Hyprland

# corectrl
sudo cp ${DOTFILESSRC}/etc/90-corectrl.rules /etc/polkit-1/rules.d/90-corectrl.rules

# ryzen smu
sudo cp ${DOTFILESSRC}/etc/ryzen_smu.conf /etc/modules-load.d/ryzen_smu.conf

# alsa soft mixer
mkdir -p ~/.config/wireplumber/wireplumber.conf.d/
cp ${DOTFILESSRC}/etc/alsa-soft-mixer.conf /etc/wireplumber/wireplumber.conf.d/alsa-soft-mixer.lua
cp ${DOTFILESSRC}/etc/alsa-soft-mixer.conf ~/.config/wireplumber/wireplumber.conf.d/alsa-soft-mixer.lua

# audio
sudo cp ${DOTFILESSRC}/etc/audio.conf /etc/modprobe.d/audio.conf

# samba
sudo cp "${DOTFILESSRC}/etc/smb.conf" /etc/samba/smb.conf
sudo systemctl enable smb.service --now
sudo systemctl enable nmb.service --now

# GDM Scaling
sudo cp ${DOTFILESSRC}/etc/93_hidpi.gschema.override /usr/share/glib-2.0/schemas/93_hidpi.gschema.override

sudo glib-compile-schemas /usr/share/glib-2.0/schemas

# dotfiles
rm -rf ~/.icons && ln -s "${DOTFILESSRC}/.icons" ~/.icons
rm -rf ~/.wallpaper && ln -s "${DOTFILESSRC}/.wallpaper" ~/.wallpaper
rm -rf ~/.zshrc && ln -s "${DOTFILESSRC}/.zshrc" ~/.zshrc
rm -rf ~/.fonts && ln -s "${DOTFILESSRC}/.fonts" ~/.fonts
rm -rf ~/.gitconfig && ln -s "${DOTFILESSRC}/.gitconfig" ~/.gitconfig
rm -rf ~/.config/mimeapps.list && ln -s "${DOTFILESSRC}/.config/mimeapps.list" ~/.config/mimeapps.list
rm -rf ~/.config/gtk-3.0 && ln -s "${DOTFILESSRC}/.config/gtk-3.0" ~/.config/gtk-3.0
rm -rf ~/.config/gtk-4.0 && ln -s "${DOTFILESSRC}/.config/gtk-4.0" ~/.config/gtk-4.0
rm -rf ~/.config/kitty && ln -s "${DOTFILESSRC}/.config/kitty" ~/.config/kitty
rm -rf ~/.config/zsh && ln -s "${DOTFILESSRC}/.config/zsh" ~/.config/zsh
rm -rf ~/.config/ranger && ln -s "${DOTFILESSRC}/.config/ranger" ~/.config/ranger
rm -rf ~/.config/ncspot && ln -s "${DOTFILESSRC}/.config/ncspot" ~/.config/ncspot
rm -rf ~/.config/btop && ln -s "${DOTFILESSRC}/.config/btop" ~/.config/btop
rm -rf ~/.config/richweather && ln -s "${DOTFILESSRC}/.config/richweather" ~/.config/richweather
rm -rf ~/.config/code-flags.conf && ln -s "${DOTFILESSRC}/.config/code-flags.conf" ~/.config/code-flags.conf
rm -rf ~/.config/electron13-flags.conf && ln -s "${DOTFILESSRC}/.config/electron13-flags.conf" ~/.config/electron13-flags.conf
rm -rf ~/.config/electron25-flags.conf && ln -s "${DOTFILESSRC}/.config/electron25-flags.conf" ~/.config/electron25-flags.conf
rm -rf ~/.config/hypr && ln -s "${DOTFILESSRC}/.config/hypr" ~/.config/hypr
rm -rf ~/.config/electron-flags.conf && ln -s "${DOTFILESSRC}/.config/electron25-flags.conf" ~/.config/electron-flags.conf
rm -rf ~/.config/waybar && ln -s "${DOTFILESSRC}/.config/waybar" ~/.config/waybar
rm -rf ~/.config/yazi && ln -s "${DOTFILESSRC}/.config/yazi" ~/.config/yazi
rm -rf ~/.config/lazygit && ln -s "${DOTFILESSRC}/.config/lazygit" ~/.config/lazygit
rm -rf ~/.config/bat && ln -s "${DOTFILESSRC}/.config/bat" ~/.config/bat
rm -rf ~/.config/wofi && ln -s "${DOTFILESSRC}/.config/wofi" ~/.config/wofi
rm -rf ~/.config/dunst && ln -s "${DOTFILESSRC}/.config/dunst" ~/.config/dunst
rm -rf ~/.config/uwsm && ln -s "${DOTFILESSRC}/.config/uwsm" ~/.config/uwsm

# keyboard
touch hid_apple.conf
echo "options hid_apple fnmode=0" > hid_apple.conf
sudo mv hid_apple.conf /etc/modprobe.d/hid_apple.conf

# ZSH
chsh -s /usr/bin/zsh
/usr/bin/zsh

# oh-my-zsh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k

rm ~/.zshrc && mv ~/.zshrc.pre-oh-my-zsh ~/.zshrc

typeset -g POWERLEVEL9K_INSTANT_PROMPT=quiet

#NVM
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.38.0/install.sh | bash
source ~/.bashrc
nvm install 20
npm i -g zx pnpm @ionic/cli

# Virt manager
sudo usermod -aG kvm $(whoami)
sudo usermod -aG libvirt $(whoami)
sudo usermod -aG input $(whoami)
sudo usermod -aG vboxusers $(whoami)

sudo virsh net-autostart default

sudo nano /etc/libvirt/qemu.conf
# user root group root

sudo timedatectl set-timezone Europe/Istanbul

# Flatpak
flatpak -u override --filesystem=xdg-config/gtk-3.0
flatpak -u override --filesystem=xdg-config/gtk-4.0

user_confdir="${XDG_CONFIG_HOME:-$HOME/.config}"
for dir in ${HOME}/.var/app/*; do
    flat_confdir3="${dir}/config/gtk-3.0"
    flat_confdir4="${dir}/config/gtk-4.0"
    mkdir -p "$flat_confdir3"
    mkdir -p "$flat_confdir4"

    ln -s "${user_confdir}/gtk-3.0/settings.ini" "${flat_confdir3}"/
    ln -s "${user_confdir}/gtk-3.0/gtk.css" "${flat_confdir3}"/
    ln -s "${user_confdir}/gtk-4.0/settings.ini" "${flat_confdir4}"/
    ln -s "${user_confdir}/gtk-4.0/gtk.css" "${flat_confdir4}"/
done

for dir in ${HOME}/.var/app/*; do flatpak run --command=bash<<<"gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'" "${dir##*/}"; done

# PRE FORMAT
# dump packages
pacman -Qqe > pkglist.txt
# dump aur only packages
pacman -Qmq > pkglist-aur.txt

# Checklist
[*] https://github.com/apognu/tuigreet/issues/68#issuecomment-1192683029 tuigreet-fix
[*] tuigreet cmd | command = "tuigreet -t -r --remember-session --asterisks --cmd Hyprland"
[*] Tweaks: adw-gtk3, fonts, icons, minimize
[*] Settings: Wallpaper, Workspaces, Remote Login, Power management no sleep
[*] Enable pamac-aur
[ ] Dbeaver setup
[*] Nautilus ftp setup
[*] Android Studio setup
[*] Configure timeshift
[*] Sign in to chrome
[*] Sign into github with vscode
[ ] vmware macos vmware
[ ] debian vm for dev