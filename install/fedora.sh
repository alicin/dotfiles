sudo visudo

sudo dnf update && sudo dnf upgrade

sudo dnf enable solopasha/hyprland 

sudo dnf install hyprland hyprpaper hyprpicker hypridle hyprshot hyprlock hyprland-devel \
 xdg-desktop-portal-hyprland waybar mako bat neofetch \
 btop ranger wofi zsh dunst chromium gnome-tweaks greetd tuigreet grim imv mpv \
 ranger slurp timeshift wf-recorder polkit-gnome

# codecs
sudo dnf install gstreamer1-plugins-{bad-\*,good-\*,base} gstreamer1-plugin-openh264 gstreamer1-plugin-libav --exclude=gstreamer1-plugins-bad-free-devel
sudo dnf install lame\* --exclude=lame-devel
sudo dnf group upgrade --with-optional Multimedia

# dev
sudo dnf install wayland-devel wayland-protocols-devel pango-devel cairo-devel \
 file-devel libglvnd-devel libglvnd-core-devel libjpeg-turbo-devel libwebp-devel \
 gcc-c++ libxkbcommon-devel libdrm-devel libgbm-devel cmake mesa-libgbm-devel \
 pam-devel sdbus-cpp-devel openssl openssl-devel

sudo waydroid init -s GAPPS -f -c https://ota.waydro.id/system -v https://ota.waydro.id/vendor


DOTFILESSRC=/home/ali/labs/dotfiles
alias rm=rm

# tui greet
sudo systemctl disable gdm
sudo systemctl enable greetd
sudo mkdir /usr/lib/systemd/system/greetd.service.d/
sudo cp ${DOTFILESSRC}/etc/00-nobleed.conf /usr/lib/systemd/system/greetd.service.d/00-nobleed.conf
sudo nano /etc/greetd/config.toml
# tuigreet -r --remember-session --asterisks  --cmd Hyprland


rm -rf ~/.ssh && ln -s "${DOTFILESSRC}/.ssh" ~/.ssh
rm -rf ~/.aws && ln -s "${DOTFILESSRC}/.aws" ~/.aws
rm -rf ~/.icons && ln -s "${DOTFILESSRC}/.icons" ~/.icons
rm -rf ~/.wallpaper && ln -s "${DOTFILESSRC}/.wallpaper" ~/.wallpaper
rm -rf ~/.fonts && ln -s "${DOTFILESSRC}/.fonts" ~/.fonts
rm -rf ~/.zshrc && ln -s "${DOTFILESSRC}/.zshrc" ~/.zshrc
rm -rf ~/.fonts && ln -s "${DOTFILESSRC}/.fonts" ~/.fonts
rm -rf ~/.gitconfig && ln -s "${DOTFILESSRC}/.gitconfig" ~/.gitconfig
rm -rf ~/.android && ln -s "${DOTFILESSRC}/.android" ~/.android
rm -rf ~/.config/ags && ln -s "${DOTFILESSRC}/.config/ags" ~/.config/ags
rm -rf ~/.config/gtk-3.0 && ln -s "${DOTFILESSRC}/.config/gtk-3.0" ~/.config/gtk-3.0
rm -rf ~/.config/gtk-4.0 && ln -s "${DOTFILESSRC}/.config/gtk-4.0" ~/.config/gtk-4.0
rm -rf ~/.config/wofi && ln -s "${DOTFILESSRC}/.config/wofi" ~/.config/wofi
rm -rf ~/.config/kitty && ln -s "${DOTFILESSRC}/.config/kitty" ~/.config/kitty
rm -rf ~/.config/zsh && ln -s "${DOTFILESSRC}/.config/zsh" ~/.config/zsh
rm -rf ~/.config/ranger && ln -s "${DOTFILESSRC}/.config/ranger" ~/.config/ranger
rm -rf ~/.config/nvim && ln -s "${DOTFILESSRC}/.config/nvim" ~/.config/nvim
rm -rf ~/.config/ncspot && ln -s "${DOTFILESSRC}/.config/ncspot" ~/.config/ncspot
rm -rf ~/.config/fontconfig && ln -s "${DOTFILESSRC}/.config/fontconfig" ~/.config/fontconfig
rm -rf ~/.config/cemu && ln -s "${DOTFILESSRC}/.config/cemu" ~/.config/cemu
rm -rf ~/.config/btop && ln -s "${DOTFILESSRC}/.config/btop" ~/.config/btop
rm -rf ~/.config/code-flags.conf && ln -s "${DOTFILESSRC}/.config/code-flags.conf" ~/.config/code-flags.conf
rm -rf ~/.config/electron13-flags.conf && ln -s "${DOTFILESSRC}/.config/electron13-flags.conf" ~/.config/electron13-flags.conf
rm -rf ~/.config/electron25-flags.conf && ln -s "${DOTFILESSRC}/.config/electron25-flags.conf" ~/.config/electron25-flags.conf
rm -rf ~/.config/hypr && ln -s "${DOTFILESSRC}/.config/hypr" ~/.config/hypr
rm -rf ~/.config/electron-flags.conf && ln -s "${DOTFILESSRC}/.config/electron25-flags.conf" ~/.config/electron-flags.conf
rm -rf ~/.config/waybar && ln -s "${DOTFILESSRC}/.config/waybar" ~/.config/waybar
rm -rf ~/.config/mako && ln -s "${DOTFILESSRC}/.config/mako" ~/.config/mako

# ZSH
chsh -s /usr/bin/zsh

# oh-my-zsh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k

rm ~/.zshrc && mv ~/.zshrc.pre-oh-my-zsh ~/.zshrc

#NVM
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.38.0/install.sh | bash
source ~/.bashrc
nvm install 20
npm i -g zx yarn @ionic/cli

# vimplug
sh -c 'curl -fLo "${XDG_DATA_HOME:-$HOME/.local/share}"/nvim/site/autoload/plug.vim --create-dirs https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim'

# ranger
git clone https://github.com/alexanderjeurissen/ranger_devicons ~/.config/ranger/plugins/ranger_devicons

# samba
sudo cp "${DOTFILESSRC}/etc/smb.conf" /etc/samba/smb.conf

# permission
echo "SET PERMISSIONS"s
chmod 400 ~/.ssh/id_rsa
chmod 644 ~/.ssh/config 

# Groups
sudo usermod -aG kvm $(whoami)
sudo usermod -aG libvirt $(whoami)
sudo usermod -aG input $(whoami)

# Virt
sudo virsh net-autostart default
sudo nano /etc/libvirt/qemu.conf
# user root group root

# NCSPOT
mkdir -p ~/.local/bin/scripts
cd ~/labs
mkdir workbench
cd workbench
git clone https://github.com/hrkfdn/ncspot.git
cd ncspot
cargo build
mv ./target/debug/ncspot ~/.local/bin/scripts/ncspot

# notch
sudo nano /etc/default/grub
# apple_dcp.show_notch=1 to the kernel command line. Do this by adding it to /etc/default/grub (GRUB_CMDLINE_LINUX_DEFAULT
sudo grub2-mkconfig -o /boot/grub2/grub.cfg


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
[*] Sign into github with vscode

