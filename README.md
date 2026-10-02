# Arch-headlines　

A lightweight desktop widget for Arch Linux users — displays the latest news from [archlinux.org/news](https://archlinux.org/news/) as a scrolling ticker, with inline Arch Wiki search.

![arch-headlines](https://raw.githubusercontent.com/lifehack890-stack/arch-headlines/main/%E3%82%B9%E3%82%AF%E3%83%AA%E3%83%BC%E3%83%B3%E3%82%B7%E3%83%A7%E3%83%83%E3%83%88%202026-10-01%20122104.png)

## Features

- **News ticker** — scrolling display of the latest Arch Linux news, pauses on hover
- **RSS preview** — top 2 news items are always visible
- **Tips ticker** — Arch best-practice reminders interspersed every 3 news items
- **Wiki search** — search the Arch Wiki inline, read a summary, and jump to the full article
- **EN / JA** — bilingual interface (English / Japanese), saved across sessions
- **Auto-refresh** — fetches new RSS data every hour via a systemd user timer
- **Desktop widget** — borderless, repositionable, and expandable/collapsible
- **No browser window required** — standalone GTK 3 application powered by WebKitGTK
## Why

Arch news items can contain important information about system upgrades and
changes that may require manual intervention. Missing an important news item
can cause problems during upgrades.

This widget keeps Arch Linux news visible on the desktop so important updates
are less likely to be missed.

> *"Always read the PKGBUILD before installing from AUR."*

## Requirements

- Linux
- Python 3
- python-gobject (PyGObject)
- python-cairo (PyCairo) — **required**
- GTK 3
- WebKitGTK 4.1
- curl
- systemd (required for automatic RSS refresh)

> **Note:** `install.sh` does **not** install system dependencies automatically.
> Please install the required dependencies manually before running `install.sh`.

### Arch / Manjaro

```bash
sudo pacman -S python python-gobject python-cairo gtk3 webkit2gtk-4.1 curl
```

### Bazzite / Fedora

```bash
sudo rpm-ostree install python3-gobject python3-cairo webkit2gtk4.1 curl
```

### Ubuntu / Zorin / Debian

```bash
sudo apt install python3 python3-gi python3-cairo gir1.2-webkit2-4.1 gir1.2-gtk-3.0 curl
```

### Verified package versions

The primary development environment has been verified with:

- python-gobject 3.56.3-1
- gtk3 1:3.24.52-1
- webkit2gtk-4.1 2.52.5-2
- python-cairo 1.29.0-2

## Installation

```bash
git clone https://github.com/lifehack890-stack/arch-headlines.git
cd arch-headlines
chmod +x install.sh
bash install.sh
```

`install.sh` will:

1. Copy application files to `~/.local/share/arch-widget/`
2. Run the initial RSS fetch
3. Install and enable a systemd user timer for hourly RSS refresh
4. Print the launch command

## Running

```bash
GDK_BACKEND=x11 python3 ~/.local/share/arch-widget/arch-widget-app.py
```

> **Note:** The current implementation uses the X11 GDK backend for reliable
> borderless window and window-management behavior. On Wayland sessions,
> `GDK_BACKEND=x11` is currently required.

After running `install.sh`, `arch-headlines` may also be available through
the desktop application launcher.

## Usage

| Action | Result |
|--------|--------|
| Drag header | Reposition widget |
| Click header | Expand / collapse news list |
| Hover ticker | Pause scrolling |
| Click news item | Open article in browser |
| `wiki$` search | Search Arch Wiki inline |
| Right-click | Show quit menu |
| EN / JA toggle | Switch interface language |

## File Structure

### Installed application files

```text
~/.local/share/arch-widget/
├── arch-widget.html # Main UI
├── arch-widget-app.py # GTK / WebKitGTK launcher
└── fetch-news.sh # RSS fetcher (curl → injects into HTML)
```

### Desktop integration

The repository contains a desktop launcher entry:

```text
arch-headlines.desktop
```

The current `install.sh` does not install the desktop launcher entry or
application icon automatically.

## How It Works

The browser `fetch()` API is blocked by CORS when opening local HTML files.
Instead, `fetch-news.sh` uses `curl` to retrieve the Arch Linux RSS feed and
injects the data directly into the HTML as a JavaScript variable:

```text
ARCH_NEWS_DATA
```

This avoids the need for an external proxy or API key.

Wiki search uses the [MediaWiki API](https://wiki.archlinux.org/api.php)
with `origin=*`, which supports cross-origin requests and is free to use.

### GTK / WebKitGTK integration

The application uses GTK 3 and WebKitGTK 4.1 for its desktop UI.

Some interactions require communication between the WebView and the GTK
application. JavaScript-to-Python event signaling is used for operations such
as:

- Opening external links
- Starting window movement
- Handling interactions that must be processed by GTK rather than the WebView

Mouse event handling is designed to keep normal WebView interactions,
window movement, and the right-click quit menu separate.

### Desktop launcher integration

A desktop launcher entry exists in the repository, but the current
`install.sh` does not install it automatically.

The launcher and icon integration therefore remains a manual / development
setup rather than an installed feature provided by `install.sh`.

## Known Issues

### Wayland / X11

The current implementation requires the X11 GDK backend for reliable
borderless window and window-management behavior.

Use:

```bash
GDK_BACKEND=x11 python3 ~/.local/share/arch-widget/arch-widget-app.py
```

Native Wayland support is planned for a future version.

### Widget background whitespace

When the widget is positioned near the top of the screen, expanding it may
result in unwanted whitespace below the visible content.

This appears to be caused by a mismatch between GTK window sizing and
the WebKit content viewport.

The issue is currently under investigation.

### Background resize during collapse

The transparent/glass-style background may not always resize correctly when
the widget is collapsed.

This is also related to GTK window resizing and WebKit content repainting
and remains under investigation.

### WebKitGTK / hardware acceleration warnings

On systems without full 3D acceleration, WebKitGTK may print EGL/DRI-related
warnings.

These warnings do not necessarily prevent the application from launching or
running.

## Glassmorphism

The application uses a transparent/semi-transparent background as a
fallback for environments where compositor-level blur is unavailable.

True CSS `backdrop-filter: blur()` depends on the desktop compositor and
cannot currently be guaranteed across all Linux desktop environments.

Examples:

- GNOME may require an extension such as Blur my Shell
- KDE Plasma may require KWin configuration
- Hyprland provides compositor-level blur configuration
- Sway does not provide the same blur functionality

This is considered an environment-dependent limitation rather than a core
application bug.

## Development Status

`arch-headlines` is currently in active development and is approaching a
feature-complete state.

Core functionality is implemented, including:

- Arch Linux News RSS retrieval
- News ticker
- News preview
- Arch Wiki search
- EN / JA interface
- Widget repositioning
- Expand / collapse behavior
- Right-click quit menu
- Automatic RSS refresh
- systemd user timer integration

Current development is focused primarily on UI polishing, bug fixing,
cross-desktop compatibility, and documentation.

## Verification Environment

### Primary development environment

- OS: Zorin OS
- Desktop: GNOME
- Session: X11
- Hardware: ThinkPad X260
- Backend: GTK 3 / WebKitGTK 4.1
- GDK backend: X11

> The ThinkPad X260 is currently out of service due to a hardware issue
> and requires repair. Previous verification was performed on this device
> before the hardware failure.

### Current Arch Linux verification environment

- OS: Arch Linux
- Desktop: KDE Plasma
- Session: VirtualBox guest
- Backend: GTK 3 / WebKitGTK 4.1
- Application launcher: KDE Plasma application menu

The Arch Linux / KDE Plasma environment is used to verify installation,
application behavior, and current application functionality.

Testing on additional desktop environments and compositors is recommended
before claiming full cross-desktop compatibility.

## Roadmap

- [ ] Fix whitespace on upper-screen placement
- [ ] Improve background resizing during expand/collapse
- [ ] Flatpak packaging
- [ ] AUR package (`arch-headlines`)
- [ ] Glassmorphism / Aero styling
- [ ] GTK4 port / improved native Wayland support
- [ ] Configurable position / size
- [ ] Additional desktop environment testing

## Debugging

For known bugs, root causes, fixes, launch commands, and development notes,
seesee [DEBUGGING.md](DEBUGGING.md).

## License

MIT
