#!/bin/bash

# macOS system defaults for discobot-darwin profile

echo "Setting up macOS defaults..."

# Close any open System Preferences panes, to prevent them from overriding
osascript -e 'tell application "System Preferences" to quit'


# DOCK

# Auto Hide Dock
defaults write com.apple.dock "autohide" -bool "true"

# Don't Show Recent Applications
# defaults write com.apple.dock "show-recents" -bool "false"

# Show Recent Applications
defaults write com.apple.dock show-recent-count -int 7;


# SCREENSHOTS

# Remove Shadows from Screenshots
# defaults write com.apple.screencapture "disable-shadow" -bool "true"

# Change save location
# defaults write com.apple.screencapture location -string "$HOME/Pictures/screenshots/"

# Change file format
defaults write com.apple.screencapture type -string "png"


# MENUBAR

# Hide the menu bar
defaults write NSGlobalDomain _HIHideMenuBar -bool true


# MISSION CONTROL

# Don't Automatically rearrage spaces
defaults write com.apple.dock "mru-spaces" -bool "false"



# FINDER

# Show hidden files
defaults write com.apple.Finder "AppleShowAllFiles" -bool "true"

# Show file extensions
defaults write NSGlobalDomain AppleShowAllExtensions -bool true

# Keep folders on top when sorting by name
defaults write com.apple.finder _FXSortFoldersFirst -bool true

# Disable finder animations
defaults write com.apple.finder DisableAllAnimations -bool true

# Disable warning when changing file extension
defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false

# Hide desktop icons
# defaults write com.apple.finder CreateDesktop false
# defaults write com.apple.finder ShowExternalHardDrivesOnDesktop -bool false
# defaults write com.apple.finder ShowHardDrivesOnDesktop -bool false
# defaults write com.apple.finder ShowMountedServersOnDesktop -bool false
# defaults write com.apple.finder ShowRemovableMediaOnDesktop -bool false

# Hide status bar
defaults write com.apple.finder ShowStatusBar -bool false

# Show path in title bar
defaults write com.apple.finder _FXShowPosixPathInTitle -bool true

# Avoid creating .DS_Store files on network or USB volumes
defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true
defaults write com.apple.desktopservices DSDontWriteUSBStores -bool true

# Use list view in all Finder windows by default
# NOTE: Four-letter codes for the other view modes: `icnv`, `clmv`, `glyv`
defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv"

# Show the ~/Library folder
chflags nohidden ~/Library

# Show the /Volumes folder
sudo chflags nohidden /Volumes

# Show quit option
defaults write com.apple.finder QuitMenuItem -bool true


# App Store

# Enable the automatic update check
defaults write com.apple.SoftwareUpdate AutomaticCheckEnabled -bool true

# Download newly available updates in background
defaults write com.apple.SoftwareUpdate AutomaticDownload -int 1

# Install System data files & security updates
defaults write com.apple.SoftwareUpdate CriticalUpdateInstall -int 1

# Turn on app auto-update
defaults write com.apple.commerce AutoUpdate -bool true

# Allow the App Store to reboot machine on macOS updates
defaults write com.apple.commerce AutoUpdateRestartRequired -bool true


# Safari

# Dont automaticaly open downloads
defaults write com.apple.Safari AutoOpenSafeDownloads -bool false

# Enable developer extras
defaults write com.apple.Safari IncludeDevelopMenu -bool true
defaults write com.apple.Safari WebKitDeveloperExtrasEnabledPreferenceKey -bool true
defaults write com.apple.Safari com.apple.Safari.ContentPageGroupIdentifier.WebKit2DeveloperExtrasEnabled -bool true


# MISC

# Expand save panel by default
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode -bool true
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode2 -bool true

# Expand print panel by default
defaults write NSGlobalDomain PMPrintingExpandedStateForPrint -bool true
defaults write NSGlobalDomain PMPrintingExpandedStateForPrint2 -bool true

# Automatically quit printer app once the print jobs complete
defaults write com.apple.print.PrintingPrefs "Quit When Finished" -bool true

# Disable the “Are you sure you want to open this application?” dialog
defaults write com.apple.LaunchServices LSQuarantine -bool false

# Enable full keyboard access for all controls
# NOTE: (e.g. enable Tab in modal dialogs)
# defaults write NSGlobalDomain AppleKeyboardUIMode -int 3

# Set a blazingly fast keyboard repeat rate
# defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false
# defaults write NSGlobalDomain KeyRepeat -int 1
# defaults write NSGlobalDomain InitialKeyRepeat -int 10

# Enable subpixel font rendering on non-Apple LCDs
# NOTE: Reference: https://github.com/kevinSuttle/macOS-Defaults/issues/17#issuecomment-266633501
# defaults write NSGlobalDomain AppleFontSmoothing -int 1

# Enable HiDPI display modes (requires restart)
sudo defaults write /Library/Preferences/com.apple.windowserver DisplayResolutionEnabled -bool true
# defaults write NSGlobalDomain AppleAccentColor -int 1
# defaults write NSGlobalDomain AppleHighlightColor -string "0.65098 0.85490 0.58431"
defaults write NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticWindowAnimationsEnabled -bool false


# Symbolic Keys
defaults write com.apple.symbolichotkeys.plist AppleSymbolicHotKeys -dict-add 118 "
  <dict>
    <key>enabled</key><false/>
    <key>value</key><dict>
      <key>type</key><string>standard</string>
      <key>parameters</key>
      <array>
        <integer>65535</integer>
        <integer>18</integer>
        <integer>262144</integer>
      </array>
    </dict>
  </dict>
"

defaults write com.apple.symbolichotkeys.plist AppleSymbolicHotKeys -dict-add 119 "
  <dict>
    <key>enabled</key><false/>
    <key>value</key><dict>
      <key>type</key><string>standard</string>
      <key>parameters</key>
      <array>
        <integer>65535</integer>
        <integer>19</integer>
        <integer>262144</integer>
      </array>
    </dict>
  </dict>
"

defaults write com.apple.symbolichotkeys.plist AppleSymbolicHotKeys -dict-add 120 "
  <dict>
    <key>enabled</key><false/>
    <key>value</key><dict>
      <key>type</key><string>standard</string>
      <key>parameters</key>
      <array>
        <integer>65535</integer>
        <integer>20</integer>
        <integer>262144</integer>
      </array>
    </dict>
  </dict>
"

defaults write com.apple.symbolichotkeys.plist AppleSymbolicHotKeys -dict-add 121 "
  <dict>
    <key>enabled</key><false/>
    <key>value</key><dict>
      <key>type</key><string>standard</string>
      <key>parameters</key>
      <array>
        <integer>65535</integer>
        <integer>21</integer>
        <integer>262144</integer>
      </array>
    </dict>
  </dict>
"

defaults write com.apple.symbolichotkeys.plist AppleSymbolicHotKeys -dict-add 122 "
  <dict>
    <key>enabled</key><false/>
    <key>value</key><dict>
      <key>type</key><string>standard</string>
      <key>parameters</key>
      <array>
        <integer>65535</integer>
        <integer>23</integer>
        <integer>262144</integer>
      </array>
    </dict>
  </dict>
"

defaults write com.apple.symbolichotkeys.plist AppleSymbolicHotKeys -dict-add 123 "
  <dict>
    <key>enabled</key><false/>
    <key>value</key><dict>
      <key>type</key><string>standard</string>
      <key>parameters</key>
      <array>
        <integer>65535</integer>
        <integer>22</integer>
        <integer>262144</integer>
      </array>
    </dict>
  </dict>
"

defaults write com.apple.symbolichotkeys.plist AppleSymbolicHotKeys -dict-add 124 "
  <dict>
    <key>enabled</key><false/>
    <key>value</key><dict>
      <key>type</key><string>standard</string>
      <key>parameters</key>
      <array>
        <integer>65535</integer>
        <integer>26</integer>
        <integer>262144</integer>
      </array>
    </dict>
  </dict>
"
defaults write com.apple.symbolichotkeys.plist AppleSymbolicHotKeys -dict-add 79 "
  <dict>
    <key>enabled</key><false/>
    <key>value</key><dict>
      <key>type</key><string>standard</string>
      <key>parameters</key>
      <array>
        <integer>65535</integer>
        <integer>123</integer>
        <integer>8650752</integer>
      </array>
    </dict>
  </dict>
"
defaults write com.apple.symbolichotkeys.plist AppleSymbolicHotKeys -dict-add 81 "
  <dict>
    <key>enabled</key><false/>
    <key>value</key><dict>
      <key>type</key><string>standard</string>
      <key>parameters</key>
      <array>
        <integer>65535</integer>
        <integer>124</integer>
        <integer>8650752</integer>
      </array>
    </dict>
  </dict>
"



# Restart affected applications
/System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u
killall Dock
killall Finder
killall SystemUIServer

echo "macOS defaults configured successfully!" 