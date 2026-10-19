#!/usr/bin/env bash
# arch-headlines unified installer (GTK / KDE Plasma 6 / GNOME)
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
DATA_ROOT="${XDG_DATA_HOME:-$HOME/.local/share}"
CONFIG_ROOT="${XDG_CONFIG_HOME:-$HOME/.config}"
SYSTEMD_DIR="$CONFIG_ROOT/systemd/user"
GNOME_UUID='arch-headlines@lifehack890-stack'
PLASMOID_ID='org.archlinux.arch-headlines'

fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
need_cmd() { command -v "$1" >/dev/null 2>&1 || fail "Required command not found: $1"; }
need_file() { [[ -f "$SCRIPT_DIR/$1" ]] || fail "Missing source file: $1"; }

printf '\n=== arch-headlines installer ===\n'
printf '  1) Auto Detect\n  2) GTK\n  3) KDE Plasma 6\n  4) GNOME\n  5) Cancel\n\n'
# For unattended sandbox tests: ARCH_HEADLINES_FRONTEND=auto|gtk|kde|gnome|cancel
case "${ARCH_HEADLINES_FRONTEND:-}" in
    '') read -r -p 'Select [1-5]: ' choice || exit 1 ;;
    auto) choice=1 ;;
    gtk) choice=2 ;;
    kde) choice=3 ;;
    gnome) choice=4 ;;
    cancel) choice=5 ;;
    *) fail 'Invalid ARCH_HEADLINES_FRONTEND; use auto, gtk, kde, gnome or cancel.' ;;
esac

case "$choice" in
    1)
        desktop="${XDG_CURRENT_DESKTOP:-${XDG_SESSION_DESKTOP:-}}"
        case ":${desktop^^}:" in
            *KDE*|*PLASMA*) frontend=kde ;;
            *GNOME*|*ZORIN*) frontend=gnome ;;
            *) frontend=gtk ;;
        esac
        printf 'Auto detected: %s (desktop: %s)\n' "$frontend" "${desktop:-unknown}"
        ;;
    2) frontend=gtk ;;
    3) frontend=kde ;;
    4) frontend=gnome ;;
    5) printf 'Cancelled. No changes made.\n'; exit 0 ;;
    *) fail 'Invalid option; nothing installed.' ;;
esac

# Preflight: do not create folders or change services until inputs are validated.
need_cmd systemctl
# Verify the user bus before copying any files (e.g. headless SSH sessions).
systemctl --user show-environment >/dev/null 2>&1 || fail 'systemd user session not available'
need_cmd bash
need_cmd curl
need_cmd python3
case "$frontend" in
    gtk)
        for f in arch-widget-app.py arch-widget.html fetch-news.sh arch-headlines.svg; do need_file "$f"; done
        PYTHON_BIN="$(command -v python3)"
        unit_name=arch-widget-news
        data_dir="$DATA_ROOT/arch-widget"
        fetch_target="$data_dir/fetch-news.sh"
        ;;
    kde)
        need_cmd kpackagetool6
        need_cmd flock
        for f in plasma/plasmoid/metadata.json plasma/plasmoid/contents/ui/main.qml plasma/scripts/fetch-news.sh plasma/scripts/mark-read.sh plasma/scripts/mark-all-read.sh; do need_file "$f"; done
        # Plasma 6 still needs the Plasma5Support QML compatibility module.
        # On Arch, package presence is a better test than one hardcoded QML path.
        if ! { command -v pacman >/dev/null 2>&1 && pacman -Qq plasma5support >/dev/null 2>&1; } \
           && [[ ! -d /usr/lib/qt6/qml/org/kde/plasma/plasma5support ]] \
           && [[ ! -d /usr/lib64/qt6/qml/org/kde/plasma/plasma5support ]]; then
            printf 'WARNING: plasma5support not detected; KDE widget may fail to load.\n' >&2
            printf '         Arch: sudo pacman -S plasma5support\n' >&2
        fi
        unit_name=arch-headlines-plasma-news
        data_dir="$DATA_ROOT/arch-headlines-plasma"
        fetch_target="$data_dir/fetch-news.sh"
        ;;
    gnome)
        need_cmd flock
        for f in gnome/metadata.json gnome/extension.js gnome/arch-headlines.svg gnome/fetch-news.sh gnome/mark-read.sh gnome/mark-all-read.sh; do need_file "$f"; done
        # The current GNOME extension metadata declares Shell 46 only.
        if command -v gnome-shell >/dev/null 2>&1; then
            shell_version="$(gnome-shell --version)"
            [[ "$shell_version" =~ (^|[[:space:]])46([.]|[[:space:]]|$) ]] || fail "GNOME extension currently supports Shell 46 only; detected: $shell_version"
        else
            fail 'GNOME Shell not found; this extension declares support for GNOME Shell 46 only.'
        fi
        unit_name=arch-headlines-gnome-news
        data_dir="$DATA_ROOT/arch-headlines-gnome"
        ext_dir="$DATA_ROOT/gnome-shell/extensions/$GNOME_UUID"
        fetch_target="$ext_dir/fetch-news.sh"
        ;;
esac

# systemd interprets %, quotes and backslashes specially in unit files.
# Reject unsupported path characters rather than generate a broken ExecStart.
for path in "$DATA_ROOT" "$SYSTEMD_DIR" "$fetch_target"; do
    case "$path" in
        *$'\n'*|*$'\r'*|*'"'*|*'\\'*|*'%'*|*'$'*) fail 'Install path contains unsupported character (newline, carriage return, quote, backslash, %, or $).' ;;
    esac
done

printf '\nInstalling %s frontend...\n' "$frontend"
case "$frontend" in
    gtk)
        mkdir -p "$data_dir" "$DATA_ROOT/applications" "$DATA_ROOT/icons/breeze/apps/scalable"
        cp "$SCRIPT_DIR/arch-widget-app.py" "$SCRIPT_DIR/arch-widget.html" "$SCRIPT_DIR/fetch-news.sh" "$data_dir/"
        chmod +x "$fetch_target"
        icon_path="$DATA_ROOT/icons/breeze/apps/scalable/arch-headlines.svg"
        cp "$SCRIPT_DIR/arch-headlines.svg" "$icon_path"
        cat > "$DATA_ROOT/applications/arch-headlines.desktop" <<DESKTOP
[Desktop Entry]
Type=Application
Name=Arch-headlines
Name[ja_JP]=Arch-headlines
GenericName=Arch Headlines
Comment=Arch Linux News & Wiki Widget
Exec=env GDK_BACKEND=x11 "$PYTHON_BIN" "$data_dir/arch-widget-app.py"
Icon=$icon_path
Terminal=false
StartupNotify=false
Categories=Utility;
DESKTOP
        chmod 644 "$DATA_ROOT/applications/arch-headlines.desktop"
        ;;
    kde)
        # Install the package through KDE's package manager (handles install/upgrade).
        # Exact local package directory: avoids prefix matches such as .devtest
        # and avoids grep -q / pipefail / SIGPIPE interactions.
        if [[ -d "$DATA_ROOT/plasma/plasmoids/$PLASMOID_ID" ]]; then
            kpackagetool6 --type Plasma/Applet --upgrade "$SCRIPT_DIR/plasma/plasmoid"
        else
            kpackagetool6 --type Plasma/Applet --install "$SCRIPT_DIR/plasma/plasmoid"
        fi
        mkdir -p "$data_dir"
        cp "$SCRIPT_DIR/plasma/scripts/"*.sh "$data_dir/"
        chmod +x "$data_dir/"*.sh
        ;;
    gnome)
        mkdir -p "$data_dir" "$ext_dir"
        cp "$SCRIPT_DIR/gnome/metadata.json" "$SCRIPT_DIR/gnome/extension.js" "$SCRIPT_DIR/gnome/arch-headlines.svg" "$ext_dir/"
        cp "$SCRIPT_DIR/gnome/"*.sh "$ext_dir/"
        chmod +x "$ext_dir/"*.sh
        ;;
esac

mkdir -p "$SYSTEMD_DIR"
cat > "$SYSTEMD_DIR/$unit_name.service" <<UNIT
[Unit]
Description=Arch Headlines news fetcher ($frontend)
Wants=network-online.target
After=network-online.target

[Service]
Type=oneshot
Environment="XDG_DATA_HOME=$DATA_ROOT"
ExecStart=/usr/bin/bash "$fetch_target"
UNIT

cat > "$SYSTEMD_DIR/$unit_name.timer" <<UNIT
[Unit]
Description=Arch Headlines hourly news refresh ($frontend)

[Timer]
OnBootSec=30sec
OnUnitActiveSec=1h
RandomizedDelaySec=5min

[Install]
WantedBy=timers.target
UNIT

systemctl --user daemon-reload
systemctl --user enable --now "$unit_name.timer"

# Initial fetch is best-effort: offline installations remain usable.
if ! bash "$fetch_target"; then
    printf 'WARNING: Initial news fetch failed; the timer will retry later.\n' >&2
fi

printf '\nInstalled: %s\nNews timer: %s.timer\n' "$frontend" "$unit_name"
case "$frontend" in
    gtk) printf 'Launch: Arch-headlines (application menu)\n' ;;
    kde)
        printf 'KDE Plasma: Add the "Arch Headlines" widget from Edit Mode (if newly installed).\n'
        printf 'After an upgrade, log out and back in to ensure updated QML is loaded.\n'
        ;;
    gnome) printf 'Log out/in to load the extension, then run: gnome-extensions enable %s\n' "$GNOME_UUID" ;;
esac
