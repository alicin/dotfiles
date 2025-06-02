# Profile-based Dotfiles

A modern, machine-specific dotfiles management system using JSON-based profile configurations.

## Overview

This dotfiles system is organized around **profiles** that represent specific computer/OS combinations. Each profile contains its own package lists, configuration files, and setup scripts tailored to that specific environment.

## Available Profiles

| Profile           | Description                            | OS      | Architecture |
| ----------------- | -------------------------------------- | ------- | ------------ |
| `discobot-darwin` | Mac laptop running macOS               | macOS   | ARM64        |
| `discobot-fedora` | Mac laptop running Fedora Linux        | Fedora  | AArch64      |
| `mcu-arch`        | Desktop workstation running Arch Linux | Arch    | x86_64       |
| `mcu-win`         | Desktop workstation running Windows    | Windows | x86_64       |
| `m4rv1n-arch`     | Tablet running Arch Linux              | Arch    | x86_64       |

## Quick Start

### Auto-detection (Recommended)

```bash
./profile-install.sh --auto
```

### Manual Profile Selection

```bash
# List available profiles
./profile-install.sh --list

# Install specific profile
./profile-install.sh discobot-darwin

# Dry run to see what would be installed
./profile-install.sh mcu-arch --dry-run
```

### Partial Installation

```bash
# Install packages only
./profile-install.sh discobot-darwin --packages-only

# Link configurations only
./profile-install.sh discobot-darwin --configs-only

# Run scripts only
./profile-install.sh discobot-darwin --scripts-only
```

## Project Structure

```
dotfiles/
├── profiles/                   # Profile configurations
│   ├── discobot-darwin/        # macOS laptop profile
│   │   ├── profile.json        # Profile configuration
│   │   └── packages/           # Package files
│   │       └── Brewfile        # Homebrew packages
│   ├── discobot-fedora/        # Fedora laptop profile
│   │   ├── profile.json
│   │   └── packages/
│   │       ├── dnf.txt         # DNF packages
│   │       └── flatpak.txt     # Flatpak applications
│   ├── mcu-arch/               # Arch desktop profile
│   │   ├── profile.json
│   │   └── packages/
│   │       ├── pacman.txt      # Pacman packages
│   │       └── aur.txt         # AUR packages
│   ├── mcu-win/                # Windows desktop profile
│   │   ├── profile.json
│   │   └── packages/
│   │       ├── winget.txt      # Winget packages
│   │       └── scoop.txt       # Scoop packages
│   └── m4rv1n-arch/            # Arch tablet profile
├── scripts/                    # Shared installation scripts
│   ├── setup_macos_defaults.sh
│   ├── setup_arch_aur.sh
│   ├── setup_arch_services.sh
│   ├── setup_fedora_repos.sh
│   ├── setup_fedora_services.sh
│   ├── setup_gaming.sh
│   ├── setup_tablet_specifics.sh
│   ├── setup_windows_features.ps1
│   ├── setup_windows_defaults.ps1
│   └── setup_wsl.ps1
├── config/                     # Shared configuration files
├── dotfiles/                   # Shared dotfiles
├── themes/                     # Themes and assets
├── lib/                        # Utility libraries
└── install.sh                  # Main installer script
```

## Profile Configuration

Each profile is defined by a `profile.json` file with the following structure:

```json
{
  "name": "profile-name",
  "description": "Profile description",
  "hostname": "expected-hostname",
  "os": "macos|arch|fedora|windows",
  "arch": "arm64|x86_64|aarch64",
  "package_managers": {
    "homebrew": {
      "enabled": true,
      "file": "Brewfile"
    }
  },
  "configs": ["zsh", "git", "nvim"],
  "dotfiles": ["zshrc", "gitconfig"],
  "themes": ["fonts", "wallpapers"],
  "scripts": {
    "pre_install": [],
    "post_install": ["setup_defaults.sh"]
  },
  "environment": {
    "BROWSER": "firefox",
    "TERMINAL": "kitty"
  },
  "features": {
    "gaming": true,
    "virtualization": false
  }
}
```

## Package Managers

The system supports multiple package managers per profile:

- **macOS**: Homebrew (`Brewfile`)
- **Arch Linux**: pacman (`pacman.txt`) + AUR via yay (`aur.txt`)
- **Fedora**: DNF (`dnf.txt`) + Flatpak (`flatpak.txt`)
- **Windows**: Winget (`winget.txt`) + Scoop (`scoop.txt`)

## Configuration Management

Configurations are organized in three categories:

1. **Dotfiles**: Files linked to `~/.*` (e.g., `.zshrc`, `.gitconfig`)
2. **Configs**: Directories linked to `~/.config/*` (e.g., `nvim`, `hypr`)
3. **Themes**: Asset directories like fonts, wallpapers, icons

## Scripts

Profile scripts are stored in the main `scripts/` directory and can be shared across multiple profiles. Each profile references the scripts it needs in its `profile.json` configuration.

**Available Scripts:**

- **macOS**: `setup_macos_defaults.sh` - Configure macOS system defaults
- **Arch Linux**: `setup_arch_aur.sh`, `setup_arch_services.sh` - AUR setup and system services
- **Fedora**: `setup_fedora_repos.sh`, `setup_fedora_services.sh` - Repository and service configuration
- **Gaming**: `setup_gaming.sh` - Gaming environment setup (cross-platform)
- **Tablet**: `setup_tablet_specifics.sh` - Tablet-specific optimizations
- **Windows**: `setup_windows_features.ps1`, `setup_windows_defaults.ps1`, `setup_wsl.ps1` - Windows configuration

Scripts run at different stages:

- **Pre-install**: Run before package installation (e.g., repository setup)
- **Post-install**: Run after configuration linking (e.g., system defaults)

Scripts support both Bash (`.sh`) and PowerShell (`.ps1`) formats and are automatically detected by file extension.

## Command Line Options

```bash
Usage: ./profile-install.sh [profile] [options]

Options:
  -h, --help           Show help
  -l, --list          List available profiles
  -a, --auto          Auto-detect profile based on hostname
  -d, --dry-run       Show what would be installed without installing
  -p, --packages-only Install packages only
  -c, --configs-only  Link configurations only
  -s, --scripts-only  Run scripts only
  -f, --force         Force installation without prompts
  -v, --verbose       Verbose output
```

## Creating a New Profile

1. Create a new directory under `profiles/` with your profile name
2. Create a `profile.json` configuration file
3. Add package files under `packages/`
4. Add any custom scripts under `scripts/`
5. Test with `--dry-run` before running

## Migration from Legacy System

The original `install.sh` is still available but deprecated. To migrate:

1. Use the new `profile-install.sh` instead
2. Machine-specific configurations are now in profiles
3. Package lists are organized by profile and package manager

## Dependencies

- `jq` for JSON parsing
- `git` for repository management
- Platform-specific package managers (brew, pacman, dnf, etc.)

## Examples

```bash
# Auto-detect and install current machine's profile
./profile-install.sh --auto --force

# Install desktop workstation profile with dry-run first
./profile-install.sh mcu-arch --dry-run
./profile-install.sh mcu-arch

# Update only configurations for laptop
./profile-install.sh discobot-darwin --configs-only

# Install packages for Windows profile
./profile-install.sh mcu-win --packages-only
```
