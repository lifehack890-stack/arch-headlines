#!/bin/bash
# install.sh — arch-headlines setup
set -euo pipefail

DATA_ROOT="${XDG_DATA_HOME:-$HOME/.local/share}"
DATA_DIR="$DATA_ROOT/arch-widget"
APPLICATIONS_DIR="$DATA_ROOT/applications"
SYSTEMD_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "→ creating data dir: $DATA_DIR"
mkdir -p "$DATA_DIR"

echo "→ installing application files"
cp "$SCRIPT_DIR/arch-widget-app.py" "$DATA_DIR/"
cp "$SCRIPT_DIR/arch-widget.html" "$DATA_DIR/"
cp "$SCRIPT_DIR/fetch-news.sh" "$DATA_DIR/"
cp "$SCRIPT_DIR/arch-headlines.png" "$DATA_DIR/" 2>/dev/null || true
chmod +x "$DATA_DIR/fetch-news.sh"

echo "→ installing systemd user units"
mkdir -p "$SYSTEMD_DIR"
cp "$SCRIPT_DIR/arch-widget-news.service" "$SYSTEMD_DIR/"
cp "$SCRIPT_DIR/arch-widget-news.timer" "$SYSTEMD_DIR/"

echo "→ enabling and starting timer"
systemctl --user daemon-reload
systemctl --user enable --now arch-widget-news.timer

echo "→ running initial fetch"
bash "$DATA_DIR/fetch-news.sh"

echo "→ installing desktop entry"
mkdir -p "$APPLICATIONS_DIR"

PYTHON_BIN="$(command -v python3)"

cat > "$APPLICATIONS_DIR/arch-headlines.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=arch-headlines
Name[ja_JP]=arch-headlines
GenericName=Arch Headlines
GenericName[ja_JP]=Arch Headlines
Comment=Arch Linux News & Wiki Widget
Comment[ja_JP]=Arch Linux News & Wiki Widget
Exec=env GDK_BACKEND=x11 "$PYTHON_BIN" "$DATA_DIR/arch-widget-app.py"
Icon=$DATA_DIR/arch-headlines.png
Terminal=false
StartupNotify=false
Categories=Utility;
EOF

chmod 644 "$APPLICATIONS_DIR/arch-headlines.desktop"

echo ""
echo "✓ done!"
echo ""
echo "Launch from the application menu:"
echo "  arch-headlines"
echo ""
echo "Or launch manually with:"
echo "  GDK_BACKEND=x11 $PYTHON_BIN $DATA_DIR/arch-widget-app.py"
