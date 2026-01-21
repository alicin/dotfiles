#!/usr/bin/env bash
set -euo pipefail

PARAMS=(
  "i915.enable_dpcd_backlight=1"
  "nvidia.NVreg_EnableBacklighthandler=0"
  "nvidia.NVreg_RegistryDwords=EnableBrightnessControl=0"
)

DRY_RUN=0
if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=1
fi

need_root() {
  if [[ $EUID -ne 0 ]]; then
    echo "Run as root: sudo $0"
    exit 1
  fi
}

backup_file() {
  local f="$1"
  local ts
  ts="$(date +%Y%m%d-%H%M%S)"
  cp -a "$f" "${f}.bak.${ts}"
  echo "  backup -> ${f}.bak.${ts}"
}

ensure_params_in_string() {
  local s="$1"
  for p in "${PARAMS[@]}"; do
    if ! grep -qwF -- "$p" <<<"$s"; then
      s="${s} ${p}"
    fi
  done
  # normalize whitespace
  echo "$s" | tr -s ' ' | sed 's/^ //; s/ $//'
}

update_etc_kernel_cmdline() {
  local f="/etc/kernel/cmdline"
  [[ -f "$f" ]] || return 0

  echo "Updating $f ..."
  local old new
  old="$(cat "$f")"
  new="$(ensure_params_in_string "$old")"

  if [[ "$old" == "$new" ]]; then
    echo "  no change"
    return 0
  fi

  backup_file "$f"
  if [[ $DRY_RUN -eq 1 ]]; then
    echo "  (dry-run) would write:"
    echo "  $new"
  else
    printf '%s\n' "$new" > "$f"
    echo "  updated"
  fi
}

find_entries_dirs() {
  # common ESP mount layouts on Arch
  local candidates=(
    "/boot/loader/entries"
    "/efi/loader/entries"
    "/boot/efi/loader/entries"
    "/mnt/boot/loader/entries"
  )

  for d in "${candidates[@]}"; do
    if [[ -d "$d" ]]; then
      echo "$d"
    fi
  done
}

update_entry_file() {
  local f="$1"

  # find the first "options ..." line (allow indentation)
  local line
  line="$(grep -m1 -E '^[[:space:]]*options[[:space:]]+' "$f" || true)"
  if [[ -z "$line" ]]; then
    echo "  skip (no options line): $f"
    return 0
  fi

  local prefix opts new_opts
  prefix="$(sed -E 's/^([[:space:]]*options)[[:space:]]+.*/\1/' <<<"$line")"
  opts="$(sed -E 's/^[[:space:]]*options[[:space:]]+//' <<<"$line")"
  new_opts="$(ensure_params_in_string "$opts")"

  if [[ "$opts" == "$new_opts" ]]; then
    echo "  no change: $f"
    return 0
  fi

  echo "  updating: $f"
  backup_file "$f"

  if [[ $DRY_RUN -eq 1 ]]; then
    echo "  (dry-run) would set:"
    echo "  ${prefix} ${new_opts}"
  else
    # replace only the first matching options line
    awk -v new_line="${prefix} ${new_opts}" '
      BEGIN{done=0}
      {
        if (!done && $0 ~ /^[[:space:]]*options[[:space:]]+/) {
          print new_line
          done=1
        } else {
          print $0
        }
      }
    ' "$f" > "${f}.tmp"
    mv "${f}.tmp" "$f"
  fi
}

update_loader_entries() {
  local found=0
  while IFS= read -r entries_dir; do
    found=1
    echo "Scanning $entries_dir ..."
    shopt -s nullglob
    local files=("$entries_dir"/*.conf)
    shopt -u nullglob

    if (( ${#files[@]} == 0 )); then
      echo "  no entry files found"
      continue
    fi

    for f in "${files[@]}"; do
      update_entry_file "$f"
    done
  done < <(find_entries_dirs)

  if [[ $found -eq 0 ]]; then
    echo "No systemd-boot entries directory found (expected something like /boot/loader/entries)."
    echo "If your ESP is mounted somewhere unusual, mount it and re-run."
    exit 2
  fi
}

need_root
update_etc_kernel_cmdline
update_loader_entries

echo
echo "Done."
echo "Next: reboot and verify with: cat /proc/cmdline"
if [[ $DRY_RUN -eq 1 ]]; then
  echo "(You used --dry-run, so nothing was changed.)"
fi
