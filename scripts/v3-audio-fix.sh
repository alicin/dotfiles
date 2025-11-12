#!/usr/bin/env bash
set -euo pipefail

COMMON_FILE="/usr/share/alsa-card-profile/mixer/paths/analog-output.conf.common"
HP_FILE="/usr/share/alsa-card-profile/mixer/paths/analog-output-headphones.conf"

MASTER_BLOCK_COMMON=$'[Element Master]\nswitch = mute\nvolume = ignore\n'
MASTER_BLOCK_HP=$'[Element Master]\nswitch = mute\nvolume = ignore\noverride-map.1 = all\noverride-map.2 = all-left,all-right\n'

timestamp() { date +"%Y%m%d-%H%M%S"; }

backup_file() {
  local f="$1"
  if [[ -f "$f" ]]; then
    local b="${f}.bak-$(timestamp)"
    cp -a -- "$f" "$b"
    echo "Backed up: $f -> $b"
  else
    echo "ERROR: $f not found" >&2
    exit 1
  fi
}

ensure_root() {
  if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
    echo "Please run as root (e.g., sudo bash $0)" >&2
    exit 1
  fi
}

insert_master_before_pcm_common() {
  local f="$COMMON_FILE"
  # If the Master block with volume=ignore already exists, do nothing.
  if awk '
    BEGIN{found=0}
    /^\[Element Master\]/{inm=1; next}
    /^\[Element /{inm=0}
    inm && $0 ~ /^volume[[:space:]]*=[[:space:]]*ignore$/{found=1}
    END{exit found?0:1}
  ' "$f"; then
    echo "analog-output.conf.common: desired [Element Master] already present; skipping insertion."
    return
  fi

  # Insert our block before the first [Element PCM]
  local tmp
  tmp="$(mktemp)"
  awk -v block="$MASTER_BLOCK_COMMON" '
    BEGIN {inserted=0}
    /^\[Element PCM\]/ && !inserted {
      printf "%s", block
      inserted=1
    }
    { print }
    END {
      if (!inserted) {
        # If [Element PCM] not found, append at end (fallback)
        printf "%s", block
      }
    }
  ' "$f" > "$tmp"
  chmod --reference="$f" "$tmp" || true
  mv -- "$tmp" "$f"
  echo "analog-output.conf.common: inserted [Element Master] before [Element PCM]."
}

rewrite_master_block_headphones() {
  local f="$HP_FILE"
  local tmp
  tmp="$(mktemp)"

  # If the Master block already matches exactly (ignore whitespace), skip rewriting
  if awk -v RS= -v ORS= '
    function norm(s){ gsub(/[ \t\r]+/," ",s); gsub(/\n+/,"\n",s); return s }
    { content = $0 }
    END {
      wanted = "[Element Master]\nswitch = mute\nvolume = ignore\noverride-map.1 = all\noverride-map.2 = all-left,all-right\n"
      block=""
      split(content, lines, "\n")
      in=0
      for (i=1;i<=length(lines);i++){
        if (lines[i] ~ /^\[Element Master\]/){ in=1; block=lines[i] "\n"; next }
        if (in && lines[i] ~ /^\[Element /){ in=0 }
        if (in){ block = block lines[i] "\n" }
      }
      if (norm(block) == norm(wanted)) exit 0; else exit 1
    }
  ' "$f"; then
    echo "analog-output-headphones.conf: desired [Element Master] already present; skipping rewrite."
    return
  fi

  awk -v block="$MASTER_BLOCK_HP" '
    BEGIN { in_master=0; wrote=0 }
    /^\[Element Master\]/ {
      if (!wrote){
        print block
        wrote=1
      }
      in_master=1
      next
    }
    /^\[Element / {
      if (in_master){ in_master=0 }
      # If we reach another element and we have not yet written the master block
      # (e.g., malformed file), do nothing special here; continue printing
    }
    {
      if (!in_master) print
      # skip original lines inside Master block
    }
    END {
      # If Master block was never found, append it
      if (!wrote){
        printf "%s", block
      }
    }
  ' "$f" > "$tmp"
  chmod --reference="$f" "$tmp" || true
  mv -- "$tmp" "$f"
  echo "analog-output-headphones.conf: rewrote [Element Master] block."
}

restart_wireplumber() {
  if command -v systemctl >/dev/null 2>&1; then
    if systemctl --user status wireplumber.service >/dev/null 2>&1; then
      # Use machinectl to detect if we’re root and need to target the current user session.
      if [[ ${SUDO_USER:-} ]]; then
        # Restart for invoking user, not root
        sudo -u "$SUDO_USER" systemctl --user restart wireplumber.service || true
      else
        systemctl --user restart wireplumber.service || true
      fi
      echo "Restarted wireplumber (user service)."
    else
      echo "Note: wireplumber user service not found or not active; skipping restart."
      echo "You can restart manually later with: systemctl --user restart wireplumber.service"
    fi
  else
    echo "systemctl not found; please restart your audio session manually."
  fi
}

main() {
  ensure_root
  echo "== ALSA Global Volume Control workaround =="
  backup_file "$COMMON_FILE"
  backup_file "$HP_FILE"

  insert_master_before_pcm_common
  rewrite_master_block_headphones
  restart_wireplumber

  echo "All done."
}

main "$@"
