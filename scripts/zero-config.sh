#!/bin/bash

# Zero (Debian) specific post-install configuration
# NOTE: CLI tools (atuin, starship, lazygit, fnm) are now installed via Homebrew (Brewfile)
# NOTE: External repos (Docker, VS Code, Chrome, Tailscale) are set up in prepare.sh
# NOTE: Groups, QEMU, samba, flatpak are handled by finalize.sh (shared across profiles)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

source "${SCRIPT_DIR}/../lib/logging.sh"
source "${SCRIPT_DIR}/../lib/os-detection.sh"

if ! is_debian; then
    log_warning "zero-config.sh is only for Debian systems, skipping"
    exit 0
fi

# --- VM folder structure ---
VM_DIR="$HOME/labs/vm"
DOCKER_DIR="$VM_DIR/docker"
mkdir -p "$DOCKER_DIR"

# --- Supabase self-hosted setup ---
SUPABASE_DIR="$DOCKER_DIR/supabase"
SUPABASE_SOURCE="$SUPABASE_DIR/source"
SUPABASE_DOCKER="$SUPABASE_SOURCE/docker"

if [ ! -d "$SUPABASE_SOURCE/.git" ]; then
    log_info "Setting up Supabase self-hosted..."
    mkdir -p "$SUPABASE_SOURCE"
    git clone --depth 1 https://github.com/supabase/supabase.git "$SUPABASE_SOURCE"
else
    log_info "Supabase repo already cloned, pulling latest..."
    git -C "$SUPABASE_SOURCE" pull --ff-only || true
fi

# Generate .env with random secrets (compose must run from source/docker/ for relative volume paths)
if [ ! -f "$SUPABASE_DOCKER/.env" ] && [ -f "$SUPABASE_DOCKER/.env.example" ]; then
    cp "$SUPABASE_DOCKER/.env.example" "$SUPABASE_DOCKER/.env"
    log_info "Generating random secrets for Supabase .env..."
    (cd "$SUPABASE_DOCKER" && sh ./utils/generate-keys.sh --update-env)
    log_success "Supabase .env created with random secrets at $SUPABASE_DOCKER/.env"
fi

# Build Supabase Studio image
if ! docker image inspect supabase-studio:latest >/dev/null 2>&1; then
    log_info "Building Supabase Studio Docker image..."
    docker build "$SUPABASE_SOURCE" \
        -f "$SUPABASE_SOURCE/apps/studio/Dockerfile" \
        --target production \
        -t supabase-studio:latest
else
    log_info "Supabase Studio image already built, skipping"
fi

# Start Supabase services (must run from source/docker/ for volume mounts)
log_info "Starting Supabase services..."
(cd "$SUPABASE_DOCKER" && docker compose up -d)

# --- Home Assistant setup ---
HA_DIR="$DOCKER_DIR/homeassistant"
HA_CONFIG="$HA_DIR/config"
mkdir -p "$HA_CONFIG"

if [ ! -f "$HA_DIR/docker-compose.yml" ]; then
    log_info "Setting up Home Assistant..."
    cat > "$HA_DIR/docker-compose.yml" << 'EOF'
name: homeassistant

services:
  homeassistant:
    container_name: homeassistant
    image: ghcr.io/home-assistant/home-assistant:stable
    restart: unless-stopped
    privileged: true
    network_mode: host
    environment:
      - TZ=America/New_York
    volumes:
      - ./config:/config
      - /run/dbus:/run/dbus:ro
EOF
    log_success "Home Assistant docker-compose created at $HA_DIR"
fi

log_info "Starting Home Assistant..."
docker compose -f "$HA_DIR/docker-compose.yml" up -d

# --- Plex Media Server setup ---
PLEX_DIR="$DOCKER_DIR/plex"
PLEX_CONFIG="$PLEX_DIR/config"
mkdir -p "$PLEX_CONFIG"

if [ ! -f "$PLEX_DIR/docker-compose.yml" ]; then
    log_info "Setting up Plex Media Server..."
    cat > "$PLEX_DIR/docker-compose.yml" << 'EOF'
name: plex

services:
  plex:
    container_name: plex
    image: plexinc/pms-docker:latest
    restart: unless-stopped
    network_mode: host
    environment:
      - TZ=America/New_York
      - PLEX_CLAIM=${PLEX_CLAIM:-}
    volumes:
      - ./config:/config
      - /mnt/vault:/data
EOF

    cat > "$PLEX_DIR/.env" << 'EOF'
# Get a claim token from https://www.plex.tv/claim/ (valid 4 minutes)
# Only needed on first run to link the server to your Plex account
PLEX_CLAIM=
EOF
    log_success "Plex docker-compose created at $PLEX_DIR"
    log_warning "To claim your Plex server, get a token from https://www.plex.tv/claim/ and set PLEX_CLAIM in $PLEX_DIR/.env before first start"
fi

log_info "Starting Plex Media Server..."
docker compose -f "$PLEX_DIR/docker-compose.yml" --env-file "$PLEX_DIR/.env" up -d

log_success "zero-config.sh complete!"
