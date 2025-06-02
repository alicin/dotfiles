# Dotfiles

A modern, well-organized dotfiles repository with cross-platform support for macOS and Linux.

## ✨ Features

- **Cross-platform**: Supports macOS, Arch Linux, and Fedora
- **Profile-based installation**: Choose what you need (minimal, desktop, development, media, full)
- **Modular design**: Clear separation of concerns
- **Safe installation**: Automatic backups before changes
- **Easy management**: Simple commands for installation and updates
- **Modern tools**: Includes configurations for modern CLI tools

## 🚀 Quick Start

```bash
# Clone the repository
git clone <your-repo-url> ~/.dotfiles
cd ~/.dotfiles/dotfiles

# Install minimal profile (shell + essential tools)
./install.sh minimal

# Or install everything
./install.sh full

# See all available profiles
./install.sh --list
```

## 📦 Installation Profiles

Choose the profile that fits your needs:

| Profile       | Description                                   | Includes                           |
| ------------- | --------------------------------------------- | ---------------------------------- |
| `minimal`     | Core shell configuration and essential tools  | zsh, git, bat                      |
| `desktop`     | Full desktop environment with window managers | + btop, yabai, hypr, waybar, dunst |
| `development` | Development tools and programming environment | + nvim, lazygit, ranger, yazi      |
| `media`       | Media creation and editing tools              | + ncspot, recording tools          |
| `full`        | Everything - complete installation            | All configurations and tools       |

## 🛠 Installation Options

### Profile Installation

```bash
# Install specific profile
./install.sh desktop

# Dry run (see what would be installed)
./install.sh desktop --dry-run

# Force install without prompts
./install.sh full --force
```

### Partial Installation

```bash
# Install packages only
./install.sh minimal --packages-only

# Link configurations only
./install.sh desktop --configs-only
```

### Management Commands

```bash
# List available profiles
./install.sh --list

# Get help
./install.sh --help

# Backup current config
./scripts/development/dotfiles-manager.sh backup

# Verify installation
./scripts/development/dotfiles-manager.sh verify
```

## 📁 Structure

```
├── install/          # Installation and bootstrap scripts
├── packages/         # Package lists for different systems
├── config/           # Application configurations
├── scripts/          # Utility scripts
├── themes/           # Visual themes (wallpapers, icons, fonts)
├── system/           # System-level configuration files
├── dotfiles/         # Traditional dotfiles (zshrc, gitconfig, etc.)
├── lib/              # Shared utilities and functions
└── docs/             # Documentation
```

## 📦 Supported Systems

### macOS

- Package manager: Homebrew
- Window manager: yabai + skhd + sketchybar
- Terminal: Ghostty

### Arch Linux

- Package manager: pacman + yay (AUR)
- Window manager: Hyprland
- Display manager: greetd + tuigreet

### Fedora

- Package manager: dnf
- Window manager: Hyprland
- Display manager: greetd + tuigreet

## 🔧 Included Configurations

### Shell

- **zsh** with oh-my-zsh
- **Powerlevel10k** prompt
- Custom aliases and functions
- Environment variables

### Development

- **Neovim** - Modern text editor
- **Git** - Version control
- **Lazygit** - Git TUI

### CLI Tools

- **bat** - Better cat
- **btop** - System monitor
- **ranger** - File manager
- **yazi** - Modern file manager
- **ncspot** - Spotify TUI

### Window Management (Linux)

- **Hyprland** - Wayland compositor
- **Waybar** - Status bar
- **wofi** - Application launcher
- **dunst** - Notification daemon

### Window Management (macOS)

- **yabai** - Tiling window manager
- **skhd** - Hotkey daemon
- **sketchybar** - Menu bar replacement

## 🎨 Customization

### Adding New Configurations

1. Add your config to the appropriate directory under `config/`
2. Update the profile configuration in `install.sh`
3. Test with `./install.sh [profile] --dry-run`

### Adding New Packages

1. Add packages to the appropriate file in `packages/`
2. Update the profile package groups in `install.sh`
3. Test with `./install.sh [profile] --packages-only`

### Adding New Scripts

1. Add your script to the appropriate subdirectory in `scripts/`
2. Make it executable: `chmod +x scripts/category/your-script.sh`
3. Follow the template in `scripts/README.md`

## 🔧 Utility Scripts

The `scripts/` directory contains useful utilities:

```bash
# Dotfiles management
./scripts/development/dotfiles-manager.sh backup
./scripts/development/dotfiles-manager.sh verify

# Media tools
./scripts/media/record.sh              # Screen recording
./scripts/utilities/brightness.sh up   # Brightness control
```

See `scripts/README.md` for complete documentation.

## 🔍 Management Commands

```bash
# Create backup before making changes
./scripts/development/dotfiles-manager.sh backup

# Update dotfiles from git
./scripts/development/dotfiles-manager.sh update

# Verify all symlinks are working
./scripts/development/dotfiles-manager.sh verify

# Clean up broken symlinks
./scripts/development/dotfiles-manager.sh cleanup

# List available backups
./scripts/development/dotfiles-manager.sh list-backups
```

## 🐛 Troubleshooting

### Installation Issues

```bash
# Check what would be installed
./install.sh [profile] --dry-run

# Install packages manually
./install.sh [profile] --packages-only

# Link configs manually
./install.sh [profile] --configs-only
```

### Broken Symlinks

```bash
./scripts/development/dotfiles-manager.sh cleanup
./install.sh [profile] --configs-only
```

### Package Installation Issues

Check the logs and ensure your package manager is up to date:

```bash
# macOS
brew update

# Arch Linux
sudo pacman -Syu

# Fedora
sudo dnf update
```

### Permission Issues

Make sure scripts are executable:

```bash
chmod +x install.sh
chmod +x scripts/**/*.sh
```

## 📝 Examples

### First-time Setup

```bash
# Clone and install minimal setup
git clone <repo> ~/.dotfiles
cd ~/.dotfiles/dotfiles
./install.sh minimal

# Later add development tools
./install.sh development --configs-only
```

### Daily Usage

```bash
# Adjust screen brightness
./scripts/utilities/brightness.sh up

# Start screen recording
./scripts/media/record.sh

# Create backup before experimenting
./scripts/development/dotfiles-manager.sh backup
```

### Maintenance

```bash
# Update dotfiles
./scripts/development/dotfiles-manager.sh update

# Verify everything is working
./scripts/development/dotfiles-manager.sh verify

# Clean up any issues
./scripts/development/dotfiles-manager.sh cleanup
```

## 📝 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test on your system
5. Submit a pull request

## 📚 More Documentation

- [Installation Guide](INSTALL.md)
- [Scripts Documentation](../scripts/README.md)
- [macOS Setup](MACOS.md)
- [Linux Setup](LINUX.md)
