#!/bin/bash
# install.sh — arch-headlines setup
set -euo pipefail

DATA_ROOT="${XDG_DATA_HOME:-$HOME/.local/share}"
# XDG base directories must use absolute paths.
case "$DATA_ROOT" in
    /*) ;;
    *)
        echo "install.sh: XDG_DATA_HOME must be absolute" >&2
        exit 1
        ;;
esac

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
chmod +x "$DATA_DIR/fetch-news.sh"
ICON_DIR="$DATA_ROOT/icons/breeze/apps/scalable"
mkdir -p "$ICON_DIR"
cp "$SCRIPT_DIR/arch-headlines.svg" "$ICON_DIR/arch-headlines.svg"

echo "→ installing systemd user units"
mkdir -p "$SYSTEMD_DIR"
# Generate a service using the resolved XDG data directory.
# Encode paths for systemd unit syntax.
python3 - "$SYSTEMD_DIR/arch-widget-news.service" "$DATA_ROOT" "$DATA_DIR/fetch-news.sh" <<'PYUNIT'
from pathlib import Path
import sys

unit_path = Path(sys.argv[1])
data_root = sys.argv[2]
script_path = sys.argv[3]

def escape_systemd(value):
    return (
        value.replace(chr(92), chr(92) * 2)
             .replace('"', chr(92) + '"')
             .replace('%', '%%')
    )

unit = (
    "[Unit]\n"
    "Description=Arch Linux News Fetcher (arch-widget)\n"
    "After=network-online.target\n"
    "Wants=network-online.target\n"
    "\n"
    "[Service]\n"
    "Type=oneshot\n"
    f'Environment="XDG_DATA_HOME={escape_systemd(data_root)}"\n'
    f'ExecStart="{escape_systemd(script_path)}"\n'
)

unit_path.write_text(unit, encoding="utf-8")
PYUNIT
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
Name=Arch-headlines
Name[ja_JP]=Arch-headlines
GenericName=Arch Headlines
GenericName[ja_JP]=Arch Headlines
Comment=Arch Linux News & Wiki Widget
Comment[ja_JP]=Arch Linux News & Wiki Widget
Exec=env GDK_BACKEND=x11 "$PYTHON_BIN" "$DATA_DIR/arch-widget-app.py"
Icon=$ICON_DIR/arch-headlines.svg
Terminal=false
StartupNotify=false
Categories=Utility;
EOF

chmod 644 "$APPLICATIONS_DIR/arch-headlines.desktop"

echo ""
echo "✓ done!"
echo ""
echo "Launch from the application menu:"
echo "  Arch-headlines"
echo ""
echo "Or launch manually with:"
echo "  GDK_BACKEND=x11 $PYTHON_BIN $DATA_DIR/arch-widget-app.py"
