#!/bin/bash

# script path
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROFILE_DIR="$SCRIPT_DIR/../profiles/discobot-darwin"

set -e

REQUIREMENTS=("jq")
for cmd in "${REQUIREMENTS[@]}"; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "❌ Missing required tool: $cmd"
    exit 1
  fi
done

echo "🔧 Cleaning up Homebrew..."
brew cleanup
brew autoremove

echo "📦 Regenerating Brewfile..."
BREWFILE="$PROFILE_DIR/packages/Brewfile"
brew bundle dump --force --file="$BREWFILE"
echo "✅ Brewfile dumped to $BREWFILE"

# Cache setup
CACHE_FILE="$SCRIPT_DIR/.brew_cask_index"
CACHE_MAX_AGE_SECONDS=$((60 * 60 * 24)) # 1 day

should_refresh_cache=true
if [[ -f "$CACHE_FILE" ]]; then
  last_modified=$(stat -f "%m" "$CACHE_FILE" 2>/dev/null || stat -c "%Y" "$CACHE_FILE")
  now=$(date +%s)
  age=$((now - last_modified))
  if [[ $age -lt $CACHE_MAX_AGE_SECONDS ]]; then
    should_refresh_cache=false
  fi
fi

if $should_refresh_cache; then
  echo "📦 Refreshing Homebrew cask index..."
  brew search --casks "" > "$CACHE_FILE"
else
  echo "📦 Using cached cask index ($CACHE_FILE)"
fi

echo "📂 Listing installed GUI apps in /Applications..."
APP_NAMES=()
while IFS= read -r app; do
  APP_NAMES+=("$app")
done < <(find /Applications -maxdepth 1 -name '*.app' -exec basename {} .app \;)

NORMALIZED_APPS=()
for app in "${APP_NAMES[@]}"; do
  normalized=$(echo "$app" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')
  NORMALIZED_APPS+=("$normalized")
done

FOUND_CASKS=()
SKIP_APPS=("divvy" "safari" "xcode" "steam-link" "docker")

echo "🔍 Searching Homebrew casks for matching apps (cached)..."
for app in "${NORMALIZED_APPS[@]}"; do
  # Skip known apps
  if printf '%s\n' "${SKIP_APPS[@]}" | grep -qx "$app"; then
    echo "⏭️  Skipping: $app"
    continue
  fi

  # Force override
  if [[ "$app" == "ice" ]]; then
    echo "🎯 Forced match: ice → jordanbaird-ice"
    FOUND_CASKS+=("jordanbaird-ice")
    continue
  fi

  # Fuzzy match using cached index
  MATCH=$(grep -i "^$app" "$CACHE_FILE" | head -n1)
  if [[ -n "$MATCH" ]]; then
    echo "✅ Fuzzy match: $app → $MATCH"
    FOUND_CASKS+=("$MATCH")
  else
    echo "❌ No match for: $app"
  fi
done

# Deduplicate casks
UNIQUE_CASKS=($(printf "%s\n" "${FOUND_CASKS[@]}" | sort -u))

echo ""
echo "📦 Apps with available casks to install:"
printf '• %s\n' "${UNIQUE_CASKS[@]}"

echo ""
read -p "👉 Do you want to install these missing casks now? (y/n): " install_choice
if [[ "$install_choice" == "y" ]]; then
  for cask in "${UNIQUE_CASKS[@]}"; do
    echo "Installing $cask..."
    brew install --cask --force "$cask"
  done
  echo "✅ All selected apps installed via Homebrew."
  echo "📦 Regenerating Brewfile again..."
  brew bundle dump --force --file="$BREWFILE"
  echo "✅ Updated Brewfile written to $BREWFILE"
else
  echo "⚠️ Skipped installing apps."
fi

echo "✅ Done!"