# arch-headlines

A lightweight desktop widget for Arch Linux users — displays the latest news from [archlinux.org/news](https://archlinux.org/news/) as a scrolling ticker, with inline Arch Wiki search.


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
- `python3-gi`
- `gir1.2-webkit2-4.1` (WebKit2GTK 4.1)
- `curl`

### Arch / Manjaro
```bash
sudo pacman -S python-gobject webkit2gtk-4.1 curl
```

### Bazzite / Fedora
```bash
sudo rpm-ostree install python3-gobject webkit2gtk4.1 curl
```

### Ubuntu / Zorin / Debian
```bash
sudo apt install python3-gi gir1.2-webkit2-4.1 curl
```

## Installation

```bash
git clone https://github.com/lifehack890-stack/arch-headlines.git
cd arch-headlines
chmod +x install.sh
bash install.sh
```

`install.sh` will:
1. Copy files to `~/.local/share/arch-widget/`
2. Fetch news on first run
3. Enable systemd user timer (hourly refresh)
4. Print the path to open in your browser or via the app

## Running

```bash
# As a GTK desktop widget (no titlebar)
GDK_BACKEND=x11 python3 ~/.local/share/arch-widget/arch-widget-app.py

# Or via application launcher (after install)
# Search "arch-headlines" in your app menu
```

> **Note:** `GDK_BACKEND=x11` is required on Wayland sessions for the borderless window to work correctly.

## Usage

| Action | Result |
|--------|--------|
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

- Link clicks may not open browser on some Wayland compositors (workaround: drag link to browser)
- `GDK_BACKEND=x11` required on Wayland

## Roadmap

- [ ] Fix link click → browser on Wayland
- [ ] Flatpak packaging
- [ ] AUR package (`arch-headlines`)
- [ ] Configurable position / size
- [ ] Dark/light theme toggle

## License

MIT
