#!/usr/bin/env bash
set -euo pipefail

CONF="/etc/makepkg.conf"
DRY_RUN=0
LEAVE_FREE=0
SET_ZSTD=1

usage() {
  cat <<'EOF'
Usage:
  sudo ./enable-parallel-makepkg.sh [--leave N] [--no-zstd] [--dry-run]

Options:
  --leave N   Leave N CPU threads free (default: 0 = use all threads)
  --no-zstd   Do not modify COMPRESSZST
  --dry-run   Show what would change, but don't write

Examples:
  sudo ./enable-parallel-makepkg.sh
  sudo ./enable-parallel-makepkg.sh --leave 1
  sudo ./enable-parallel-makepkg.sh --no-zstd
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --leave)
      shift
      [[ $# -gt 0 ]] || { echo "Missing value for --leave"; exit 2; }
      LEAVE_FREE="$1"
      ;;
    --no-zstd)
      SET_ZSTD=0
      ;;
    --dry-run)
      DRY_RUN=1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown arg: $1"
      usage
      exit 2
      ;;
  esac
  shift
done

if [[ $EUID -ne 0 ]]; then
  echo "Run as root: sudo $0"
  exit 1
fi

if [[ ! -f "$CONF" ]]; then
  echo "Not found: $CONF"
  exit 1
fi

if ! command -v nproc >/dev/null 2>&1; then
  echo "nproc not found (coreutils). Install it: sudo pacman -S coreutils"
  exit 1
fi

threads="$(nproc)"
if ! [[ "$LEAVE_FREE" =~ ^[0-9]+$ ]]; then
  echo "--leave must be a non-negative integer"
  exit 2
fi

use_threads=$(( threads - LEAVE_FREE ))
if (( use_threads < 1 )); then
  use_threads=1
fi

MAKEFLAGS_LINE="MAKEFLAGS=\"-j${use_threads}\""
COMPRESSZST_LINE="COMPRESSZST=(zstd -c -T0 -)"

ts="$(date +%Y%m%d-%H%M%S)"
backup="${CONF}.bak.${ts}"

echo "Config: $CONF"
echo "CPU threads: $threads (using: $use_threads, leaving free: $LEAVE_FREE)"
echo "Backup: $backup"
echo

# Create a backup
if (( DRY_RUN == 0 )); then
  cp -a "$CONF" "$backup"
fi

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT

# Process file line-by-line to preserve comments/format as much as possible
awk -v makeflags_line="$MAKEFLAGS_LINE" \
    -v set_zstd="$SET_ZSTD" \
    -v compresszst_line="$COMPRESSZST_LINE" '
BEGIN {
  saw_makeflags=0
  saw_compresszst=0
}
{
  # Replace an uncommented MAKEFLAGS line
  if ($0 ~ /^[[:space:]]*MAKEFLAGS=/) {
    print makeflags_line
    saw_makeflags=1
    next
  }

  # If it's commented MAKEFLAGS (e.g. #MAKEFLAGS="-j2"), keep it as-is
  # and we will add our MAKEFLAGS at the end if not set.
  if ($0 ~ /^[[:space:]]*#[[:space:]]*MAKEFLAGS=/) {
    print $0
    next
  }

  # Replace an uncommented COMPRESSZST line if requested
  if (set_zstd == 1 && $0 ~ /^[[:space:]]*COMPRESSZST=/) {
    print compresszst_line
    saw_compresszst=1
    next
  }

  print $0
}
END {
  if (saw_makeflags == 0) {
    print ""
    print "# Added by enable-parallel-makepkg.sh"
    print makeflags_line
  }

  if (set_zstd == 1 && saw_compresszst == 0) {
    print ""
    print "# Added by enable-parallel-makepkg.sh"
    print compresszst_line
  }
}
' "$CONF" > "$tmp"

echo "Planned settings:"
echo "  $MAKEFLAGS_LINE"
if (( SET_ZSTD == 1 )); then
  echo "  $COMPRESSZST_LINE"
else
  echo "  (leaving COMPRESSZST unchanged)"
fi
echo

if (( DRY_RUN == 1 )); then
  echo "Dry-run enabled; no changes written."
  echo "Diff preview:"
  diff -u "$CONF" "$tmp" || true
  exit 0
fi

# Write back atomically
install -m 644 "$tmp" "$CONF"

echo "Updated $CONF"
echo "Verify:"
echo "  grep -nE '^(MAKEFLAGS=|COMPRESSZST=)' $CONF"
