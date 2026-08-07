#!/usr/bin/env bash

# Install Toshy (macOS-style keymapper) and re-attach the tracked config.
#
# Toshy is not an AUR package -- upstream ships an installer that builds a
# ~74 MB tree under ~/.config/toshy: a Python .venv, the dbus services, the GUI,
# the systemd units, the whole program. Almost none of that is config, so this
# repo tracks exactly one file out of it (see config/toshy/README.md):
#
#   toshy_config.py                -- the keymapper config; our customizations
#                                     live in its SLICE_MARK_START/END blocks
#
# toshy_user_preferences.sqlite used to be tracked and relinked here too. It no
# longer is (2026-08-07): the symlink pointed into the working tree, so Toshy
# appending to mru_layouts on every start left the repo permanently dirty on
# every host. It is now a plain per-machine file that this script must NOT
# touch -- relinking it would point ~/.config/toshy at an ignored path and
# hand back the same churn. Recovery of the last tracked copy, for a host still
# holding a dangling symlink: config/toshy/README.md.
#
# The installer writes a real file at the tracked path, so this script runs it
# FIRST and re-creates the symlink afterwards. Anything Toshy wrote is moved
# aside rather than deleted -- on a version bump the upstream template changes,
# and you want to diff it against the tracked copy instead of losing it.
#
# Safe to re-run: an existing install is upgraded in place, and the symlink is
# only rewritten if it is not already pointing at the repo.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
LIB_DIR="${DOTFILES_DIR}/lib"

source "${LIB_DIR}/logging.sh"

TOSHY_REPO="https://github.com/RedBearAK/toshy"
TOSHY_HOME="${HOME}/.config/toshy"
TRACKED_DIR="${DOTFILES_DIR}/config/toshy"
SRC_DIR="${HOME}/labs/src/toshy"

log_header "Installing Toshy"

if ! command -v git >/dev/null 2>&1; then
    log_error "git is required to install Toshy"
    exit 1
fi

# ── Fetch / update the source tree ──────────────────────────────────────────
if [[ -d "${SRC_DIR}/.git" ]]; then
    log_step "Updating existing Toshy checkout at ${SRC_DIR}"
    git -C "${SRC_DIR}" pull --ff-only
else
    log_step "Cloning Toshy to ${SRC_DIR}"
    mkdir -p "$(dirname "${SRC_DIR}")"
    git clone --depth 1 "${TOSHY_REPO}" "${SRC_DIR}"
fi

# ── Run upstream's installer ────────────────────────────────────────────────
# It handles distro detection, the venv, the systemd user units and the udev
# rules itself. --no-dbus-python is not passed: the tray/GUI want it.
#
# Two things have to be handled to run this unattended:
#
# 1. The installer adapts its config to the *detected* desktop, reading
#    XDG_SESSION_DESKTOP / XDG_CURRENT_DESKTOP / DESKTOP_SESSION. Run outside a
#    graphical session (a profile install over SSH) none of those are set, it
#    falls back to guessing 'gnome', and you end up with a GNOME-targeted
#    keymapper config on a Hyprland machine. Declare the target explicitly.
#    This also skips the GNOME-Wayland branch, which gates on a
#    type-the-secret-code prompt that no unattended run can satisfy.
#
# 2. It still asks 'Can user "<name>" run admin commands (via sudo/doas/run0)?'
#    through input(), and with no TTY that is an EOFError partway through the
#    install. Feed it 'y' -- true here, and the tracked config gets re-linked
#    below regardless of what the installer writes.
log_step "Running Toshy's installer (this takes a few minutes)"
(
    cd "${SRC_DIR}"
    export XDG_SESSION_TYPE="${XDG_SESSION_TYPE:-wayland}"
    export XDG_CURRENT_DESKTOP="${XDG_CURRENT_DESKTOP:-Hyprland}"
    export XDG_SESSION_DESKTOP="${XDG_SESSION_DESKTOP:-Hyprland}"
    # A bounded feed, not `yes y`: when the installer exits, `yes` gets SIGPIPE
    # and dies 141, which under `set -o pipefail` fails the whole pipeline and
    # aborted this script *after a successful install* but *before* the relink
    # below -- leaving the tracked config detached with no error shown.
    printf 'y\n%.0s' {1..20} | ./setup_toshy.py install
)

# ── Re-attach the tracked files ─────────────────────────────────────────────
relink() {
    local name="$1"
    local tracked="${TRACKED_DIR}/${name}"
    local live="${TOSHY_HOME}/${name}"

    if [[ ! -e "${tracked}" ]]; then
        log_warning "Not tracked in the repo, leaving Toshy's copy alone: ${name}"
        return 0
    fi

    if [[ -L "${live}" && "$(readlink -f "${live}")" == "$(readlink -f "${tracked}")" ]]; then
        log_substep "Already linked: ${name}"
        return 0
    fi

    if [[ -e "${live}" || -L "${live}" ]]; then
        local backup="${live}.installed-$(date +%Y%m%d-%H%M%S)"
        mv "${live}" "${backup}"
        log_substep "Moved Toshy's copy aside: $(basename "${backup}")"
    fi

    ln -s "${tracked}" "${live}"
    log_substep "Linked: ${name} -> ${tracked}"
}

log_step "Re-attaching tracked Toshy config"
relink "toshy_config.py"
# NOT toshy_user_preferences.sqlite -- deliberately per-machine now, see header.

# ── Sanity check ────────────────────────────────────────────────────────────
# A syntax error here means no keymapper at all, and the failure mode is a
# service that flaps rather than an obvious error, so check before restarting.
log_step "Checking toshy_config.py compiles"
if python3 -m py_compile "${TOSHY_HOME}/toshy_config.py"; then
    log_substep "toshy_config.py OK"
else
    log_error "toshy_config.py failed to compile -- not restarting the service"
    exit 1
fi

# ── Scheme canary ───────────────────────────────────────────────────────────
# The 2026-07-05 modifier scheme (physical Super/Ctrl pass through natively to
# Hyprland) lives in edits OUTSIDE the SLICE_MARK blocks, which a Toshy
# install/upgrade regenerates wholesale: the 2026-08-05 run reset even the
# user_apps slice, and only the relink above restored the scheme. The relink
# guarantees the symlink; this guards the CONTENT -- if the tracked file itself
# ever loses the scheme (bad merge, installer file adopted into the repo),
# every SUPER-based Hyprland bind dies silently at once. Restore procedure and
# out-of-slice inventory: config/toshy/README.md, "The upgrade trap".
log_step "Checking the modifier scheme survived"
LIVE_CONFIG="$(readlink -f "${TOSHY_HOME}/toshy_config.py")"
if [[ "${LIVE_CONFIG}" != "$(readlink -f "${TRACKED_DIR}/toshy_config.py")" ]]; then
    log_error "toshy_config.py is not the tracked repo file (points at: ${LIVE_CONFIG})"
    exit 1
fi
if grep -q '# ALI: Super stays native' "${LIVE_CONFIG}"; then
    log_substep "native-Super scheme present"
else
    log_error "The '# ALI: Super stays native' modmap edits are GONE from the tracked config."
    log_error "Every SUPER-based Hyprland bind will die silently. Restore from git history"
    log_error "(config/toshy/README.md, 'The upgrade trap') before restarting Toshy."
    exit 1
fi

log_step "Restarting Toshy services"
systemctl --user daemon-reload
systemctl --user restart toshy-config.service || \
    log_warning "toshy-config.service did not restart (no graphical session?)"

log_success "Toshy installed. Check the modifier behavior with: toshy-gui"
log_info "If a later Toshy upgrade replaces toshy_config.py with a real file,"
log_info "re-run this script to restore the symlink."
