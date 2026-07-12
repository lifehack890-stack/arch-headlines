#!/bin/bash
# install.sh — arch-headlines setup
set -euo pipefail

DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/arch-widget"
SYSTEMD_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "→ creating data dir: $DATA_DIR"
mkdir -p "$DATA_DIR"

echo "→ installing files"
cp "$SCRIPT_DIR/arch-widget-app.py" "$DATA_DIR/"
cp "$SCRIPT_DIR/arch-widget.html"   "$DATA_DIR/"
cp "$SCRIPT_DIR/fetch-news.sh"      "$DATA_DIR/"
cp "$SCRIPT_DIR/arch-headlines.png" "$DATA_DIR/" 2>/dev/null || true
chmod +x "$DATA_DIR/fetch-news.sh"

echo "→ installing systemd user units"
mkdir -p "$SYSTEMD_DIR"
cp "$SCRIPT_DIR/arch-widget-news.service" "$SYSTEMD_DIR/"
cp "$SCRIPT_DIR/arch-widget-news.timer"   "$SYSTEMD_DIR/"

echo "→ enabling and starting timer"
systemctl --user daemon-reload
systemctl --user enable --now arch-widget-news.timer

echo "→ running initial fetch"
bash "$DATA_DIR/fetch-news.sh"

echo ""
echo "✓ done! launch with:"
echo "  GDK_BACKEND=x11 python3 $DATA_DIR/arch-widget-app.py"
echo ""
echo "Or search 'arch-headlines' in your app menu."
