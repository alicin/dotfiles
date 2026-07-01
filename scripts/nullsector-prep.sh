#!/bin/bash

# nullsector (Debian) pre-install preparation.
# Lean, headless CLI box: bootstrap runtime tooling (Homebrew, fnm/node, pnpm)
# WITHOUT the desktop repositories (Docker/VS Code/Chrome/Tailscale/VirtualBox)
# that the shared prepare.sh pulls in on Debian.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/../lib"

source "${LIB_DIR}/logging.sh"
source "${LIB_DIR}/os-detection.sh"
source "${LIB_DIR}/runtime.sh"

if ! is_debian; then
    log_warning "nullsector-prep.sh is only for Debian systems, skipping"
    exit 0
fi

log_header "Preparing nullsector Environment"

setup_runtime_tools
