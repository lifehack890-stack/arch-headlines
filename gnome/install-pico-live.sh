#!/usr/bin/env bash
set -euo pipefail

if [[ "$#" -ne 1 || "${1:-}" != "--dry-run" ]]; then
    echo "Usage: $0 --dry-run" >&2
    exit 2
fi

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
for f in extension.js metadata.json arch-headlines.svg \
         fetch-news.sh mark-read.sh mark-all-read.sh \
         arch-headlines-pico-news.service arch-headlines-pico-news.timer; do
    if [[ ! -f "$SRC/$f" || -L "$SRC/$f" || ! -r "$SRC/$f" ]]; then
        echo "PREFLIGHT FAIL: $f" >&2
        exit 2
    fi
done
echo "Source preflight: PASS (8 files)"

EXT="$HOME/.local/share/gnome-shell/extensions/arch-headlines@lifehack890-stack"
UNITS="$HOME/.config/systemd/user"
DATA="$HOME/.local/share/arch-headlines-gnome"

echo "=== Arch-Headlines Pico: DRY RUN ==="
echo "Source: $SRC"
echo "Extension target: $EXT"
echo "Systemd target: $UNITS"
echo "Protected data: $DATA"
echo "Existing extension: $(test -d "$EXT" && echo YES || echo NO)"
echo "Planned files: 6 extension files + 2 systemd units"
echo "Actions performed: NONE"

echo ""
echo "=== Planned upgrade procedure ==="
echo "1. Validate source files and prerequisites"
echo "2. Back up the existing Pico extension"
echo "3. Prepare and validate the new extension"
echo "4. Switch versions with rollback protection"
echo "5. Install Pico systemd units after validation"
echo "6. Keep news.json and state.json untouched"
echo "Systemd activation: NOT PERFORMED"
