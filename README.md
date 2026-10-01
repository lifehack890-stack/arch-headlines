# arch-headlines

A lightweight desktop widget for Arch Linux users — displays the latest news from [archlinux.org/news](https://archlinux.org/news/) as a scrolling ticker, with inline Arch Wiki search.

![arch-headlines](https://raw.githubusercontent.com/lifehack890-stack/arch-headlines/main/%E3%82%B9%E3%82%AF%E3%83%AA%E3%83%BC%E3%83%B3%E3%82%B7%E3%83%A7%E3%83%83%E3%83%88%202026-10-01%20122104.png)

## Features

- **News ticker** — scrolling display of latest Arch Linux news, pauses on hover
- **RSS preview** — top 2 news items always visible
- **Tips ticker** — Arch best-practice reminders interspersed every 3 news items
- **Wiki search** — search the Arch Wiki inline, read a summary, jump to full article
- **EN / JA** — bilingual interface (English / Japanese), saved across sessions
- **Auto-refresh** — fetches new RSS every hour via systemd timer
- **No browser required** — standalone GTK app powered by WebKitGTK

## Why

Arch news items often require manual intervention before upgrading. Missing them can break your system. This widget keeps the news visible on your desktop so you never miss a critical update.

> *"Always read the PKGBUILD before installing from AUR."*

## Requirements

- Linux (systemd-based)
- Python 3
- python-gobject (PyGObject)
- python-cairo (PyCairo) — **required**; missing this causes `cairo.Context` foreign struct converter errors
- GTK 3
- WebKitGTK 4.1
- curl
- systemd (for auto-refresh timer)

> **Note:** `install.sh` does **not** install system dependencies automatically. Please install them manually before running `install.sh`.

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

Verified working with:
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
1. Copy files to `~/.local/share/arch-widget/`
2. Install and enable a systemd user timer for hourly RSS refresh
3. Run the initial RSS fetch
4. Print the launch command

## Running

```bash
GDK_BACKEND=x11 python3 ~/.local/share/arch-widget/arch-widget-app.py
```

> **Note:** On Wayland sessions, `GDK_BACKEND=x11` may be required for the borderless window to display correctly.

After running `install.sh`, you can also search for **arch-headlines** in your application launcher.

## Usage

| Action | Result |
|--------|--------|
| Drag header | Reposition widget |
| Click header | Expand / collapse news list |
| Hover ticker | Pause scrolling |
| Click news item | Open article in browser |
| `wiki$` search | Search Arch Wiki inline |
| Right-click | Quit |
| EN / JA toggle | Switch interface language |

## File Structure

```
~/.local/share/arch-widget/
├── arch-widget.html          # Main UI
├── arch-widget-app.py        # WebKitGTK launcher
├── fetch-news.sh             # RSS fetcher (curl → injects into HTML)
└── arch-headlines.png        # App icon
```

## How it works

The browser `fetch()` API is blocked by CORS when opening local HTML files, so instead `fetch-news.sh` uses `curl` to retrieve the RSS feed server-side and injects the data directly into the HTML as a JavaScript variable (`ARCH_NEWS_DATA`). No external proxy or API key required.

Wiki search uses the [MediaWiki API](https://wiki.archlinux.org/api.php) with `origin=*`, which supports CORS natively and is completely free.

## Known Issues

- On some Wayland compositors, clicking links may not open the external browser. `GDK_BACKEND=x11` is recommended.
- On Wayland, `GDK_BACKEND=x11` may be required for the borderless window to work correctly.
- In environments without 3D acceleration, WebKitGTK may print EGL/DRI-related warnings. These do not necessarily prevent the app from launching or running.
- White space may appear below the widget when placed near the top of the screen (GTK window height / WebKit content height mismatch — under investigation).

## Roadmap

- [ ] Fix whitespace on upper-screen placement
- [ ] Flatpak packaging
- [ ] AUR package (`arch-headlines`)
- [ ] Glassmorphism / Aero styling
- [ ] GTK4 port (native Wayland support)
- [ ] Configurable position / size

## License

MIT
