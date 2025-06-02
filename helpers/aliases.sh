DOTFILESSRC=/Users/ali/labs/dotfiles
alias rm=rm

# ZSH
rm -rf ~/.zshrc && ln -s "${DOTFILESSRC}/.zshrc" ~/.zshrc
rm -rf ~/.p10k.zsh && ln -s "${DOTFILESSRC}/.p10k.zsh" ~/.p10k.zsh
rm -rf ~/.gitconfig && ln -s "${DOTFILESSRC}/.gitconfig" ~/.gitconfig

# CLI
rm -rf ~/.config/bat && ln -s "${DOTFILESSRC}/.config/bat" ~/.config/bat
rm -rf ~/.config/btop && ln -s "${DOTFILESSRC}/.config/btop" ~/.config/btop
rm -rf ~/.config/ncspot && ln -s "${DOTFILESSRC}/.config/ncspot" ~/.config/ncspot
rm -rf ~/.config/neofetch && ln -s "${DOTFILESSRC}/.config/neofetch" ~/.config/neofetch
rm -rf ~/.config/nvim && ln -s "${DOTFILESSRC}/.config/nvim" ~/.config/nvim
rm -rf ~/.config/ranger && ln -s "${DOTFILESSRC}/.config/ranger" ~/.config/ranger
rm -rf ~/.config/zsh && ln -s "${DOTFILESSRC}/.config/zsh" ~/.config/zsh

# Window Management
rm -rf ~/.config/sketchybar && ln -s "${DOTFILESSRC}/.config/sketchybar" ~/.config/sketchybar
rm -rf ~/.config/yabai && ln -s "${DOTFILESSRC}/.config/yabai" ~/.config/yabai
rm -rf ~/.config/skhd && ln -s "${DOTFILESSRC}/.config/skhd" ~/.config/skhd
rm -rf ~/.config/borders && ln -s "${DOTFILESSRC}/.config/borders" ~/.config/borders

# ghostty
mkdir -p '/Users/ali/Library/Application Support/com.mitchellh.ghostty'
rm -rf '/Users/ali/Library/Application Support/com.mitchellh.ghostty/config'
rm -rf ~/.config/ghostty
ln -s "${DOTFILESSRC}/.config/ghostty" ~/.config/ghostty

# yazi
rm -rf ~/.config/yazi 
ln -s "${DOTFILESSRC}/.config/yazi" ~/.config/yazi
