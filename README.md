# Arch-headlines

A lightweight desktop news application for Arch Linux users — displays the latest news from [archlinux.org/news](https://archlinux.org/news/) and helps users stay informed about important system updates.

The project includes a GTK desktop widget and experimental integrations for KDE Plasma 6 and GNOME Shell 46.

![arch-headlines](https://raw.githubusercontent.com/lifehack890-stack/arch-headlines/main/%E3%82%B9%E3%82%AF%E3%83%AA%E3%83%BC%E3%83%B3%E3%82%B7%E3%83%A7%E3%83%83%E3%83%88%202026-10-01%20122104.png)

## Features

### GTK frontend

- **News ticker** — scrolling display of the latest Arch Linux news, pauses on hover
- **RSS preview** — top 2 news items are always visible
- **Tips ticker** — Arch best-practice reminders interspersed every 3 news items
- **Wiki search** — search the Arch Wiki inline, read a summary, and jump to the full article
- **EN / JA** — bilingual interface (English / Japanese), saved across sessions
- **Auto-refresh** — fetches new RSS data every hour via a systemd user timer
- **Live connection status** — connection indicator updates when network availability changes
- **Automatic reconnect refresh** — RSS is fetched again when network connectivity returns
- **Desktop widget** — borderless, repositionable, and expandable/collapsible
- **No separate browser window required** — standalone GTK 3 application powered by WebKitGTK

### KDE Plasma 6 frontend

- Native Plasma widget integration
- Compact representation for panel use
- Expandable news display
- RSS data stored in JSON format
- Read/unread state tracking
- Automatic RSS refresh through a systemd user timer

### GNOME Shell frontend

- GNOME Shell Extension integration
- Compact news display
- RSS data stored in JSON format
- Read/unread state tracking
- Automatic RSS refresh through a systemd user timer

**Note:** The three frontends do not currently provide identical features. GTK-specific functions such as inline Arch Wiki search and window repositioning should not be assumed to exist in the KDE or GNOME implementations.

## Why

Arch news items can contain important information about system upgrades and changes that may require manual intervention. Missing an important news item can cause problems during upgrades.

This project keeps Arch Linux news accessible from the desktop so important updates are less likely to be missed.

> *"Always read the PKGBUILD before installing from AUR."*

## Requirements

The unified installer supports three frontend selections: GTK, KDE Plasma 6, and GNOME Shell.

### Common requirements

- Linux
- Bash
- Python 3
- curl
- **systemd and an available systemd user session** — required by `install.sh` itself, not merely for optional RSS refresh. Installation stops if `systemctl --user` is unavailable.

### Frontend-specific requirements

| Frontend | Requirements |
|---|---|
| GTK | PyGObject, PyCairo, GTK 3, WebKitGTK 4.1 |
| KDE Plasma 6 | KDE Plasma 6, `kpackagetool6`, `flock`, **Plasma5Support QML module** |
| GNOME Shell | GNOME Shell 46, `flock` |

The KDE frontend imports `org.kde.plasma.plasma5support` in its QML, so **Plasma5Support is required to load the current widget**. On Arch Linux, its package name is `plasma5support`.

```bash
sudo pacman -S plasma5support
```

The current installer warns when Plasma5Support appears to be absent; it does not install the package automatically.

> **Important:** `install.sh` does not automatically install system dependencies. Install the required packages before running the installer.

### GTK dependencies — Arch / Manjaro

```bash
sudo pacman -S python python-gobject python-cairo gtk3 webkit2gtk-4.1 curl
```

### GTK dependencies — Bazzite

```bash
sudo rpm-ostree install python3-gobject python3-cairo webkit2gtk4.1 curl
```

The Bazzite command is retained from earlier documentation and has not been verified as part of the current integration tests. Conventional Fedora installations may require a different package-management command.

### GTK dependencies — Ubuntu / Zorin / Debian

```bash
sudo apt install python3 python3-gi python3-cairo gir1.2-webkit2-4.1 gir1.2-gtk-3.0 curl
```

These distribution-specific commands address the GTK frontend only. They are not complete KDE or GNOME installation instructions.

### Previously verified GTK package versions

The Arch Linux development environment has previously been tested with:

- python-gobject 3.56.3-1
- gtk3 1:3.24.52-1
- webkit2gtk-4.1 2.52.5-2
- python-cairo 1.29.0-2

These versions are recorded as test references, not strict minimum version requirements.

## Installation

### Development status

The unified installer has been tested locally on the `hardening` branch but has not yet been confirmed as published on `main`.

**Until the integration changes are published, cloning the default `main` branch may retrieve the earlier GTK-only installer.** The steps below describe the unified installer in the development checkout.

### Obtaining the source

Once the unified installer has been merged and published on `main`, the standard installation procedure will be:

```bash
git clone https://github.com/lifehack890-stack/arch-headlines.git
cd arch-headlines
bash install.sh
```

During development, run `bash install.sh` from the existing local checkout containing the unified installer and the `plasma/` and `gnome/` source directories. Do not assume the public `main` branch already contains those changes.

### Frontend selection

The installer provides a numbered menu:

```text
1) Auto Detect
2) GTK
3) KDE Plasma 6
4) GNOME
5) Cancel
```

**Auto Detect** selects a frontend based on the current desktop environment. Manual selection is also available.

For automated or controlled testing, the menu can be bypassed using `ARCH_HEADLINES_FRONTEND`:

```bash
ARCH_HEADLINES_FRONTEND=kde bash install.sh
```

Accepted values: `auto`, `gtk`, `kde`, `gnome`, and `cancel`. An invalid menu selection or invalid environment-variable value is rejected.

**Unsupported desktops:** Auto Detect may fall back to GTK on an unrecognized desktop. This fallback does not establish compatibility. XFCE and other unverified desktops are not currently supported integration targets.

### Installation locations

Default data root: `~/.local/share/` (or the configured `XDG_DATA_HOME`).

| Frontend | Installed application or extension | News data and helper scripts |
|---|---|---|
| GTK | `~/.local/share/arch-widget/` | Same directory; includes `fetch-news.sh` |
| KDE Plasma 6 | `~/.local/share/plasma/plasmoids/org.archlinux.arch-headlines/` | `~/.local/share/arch-headlines-plasma/`; includes `fetch-news.sh`, `mark-read.sh`, `mark-all-read.sh` |
| GNOME Shell | `~/.local/share/gnome-shell/extensions/arch-headlines@lifehack890-stack/` | `~/.local/share/arch-headlines-gnome/` for JSON; helper scripts are in the extension directory |

**KDE note:** The three shell scripts are installed in `arch-headlines-plasma/`, **not** inside the installed Plasmoid directory. The widget calls the scripts from the data directory.

The KDE and GNOME frontends maintain `news.json` and `state.json` independently. Each frontend has a separate systemd user service and timer.

The installer performs an initial RSS fetch. **If that fetch fails (for example, while offline), the installer prints a warning and continues; the timer can retry later.** This does not waive the requirement for a working systemd user session during installation.

### Desktop integration

**GTK:** Launch the application through the desktop application menu or use the command in the Running section.

**KDE Plasma 6:** Add **Arch Headlines** through the Plasma widget selector after installation. After an upgrade, a Plasma Shell restart may be enough to reload QML without a full logout. In sessions where `plasma-plasmashell.service` is active and managed by systemd, the following is one option:

```bash
systemctl --user restart plasma-plasmashell.service
```

The panel/desktop may disappear briefly during the restart. This command is environment-dependent and has **not** been validated as the project's upgrade procedure on all target systems. If it is unavailable or the updated widget does not load, log out and back in. Avoid restarting the shell while unsaved desktop work is in progress.

**GNOME Shell 46:** Log out and back in if the extension does not appear or updated JavaScript is not loaded. Enable it with:

```bash
gnome-extensions enable arch-headlines@lifehack890-stack
```

### Installation and upgrade verification

| Test | Result |
|---|---|
| Numbered menu choices 1–5 | Passed in isolated tests |
| Invalid menu choice 6 | Correctly rejected |
| Auto Detect — KDE | Passed classification test |
| Auto Detect — GNOME | Passed classification test |
| Auto Detect — Zorin | Passed classification test |
| Auto Detect — XFCE fallback to GTK | Passed classification test; XFCE compatibility unverified |
| GTK installation | Passed isolated mock test |
| KDE Plasma installation | Passed isolated mock test |
| KDE Plasma upgrade | Passed isolated mock test |
| GNOME installation | Passed isolated mock test |
| KDE Plasma upgrade on Arch-Hero | Passed in the live development environment |
| KDE systemd user timer | Confirmed active in the development environment |
| KDE widget display | Confirmed after session restart |
| Clean EndeavourOS installation | Pending |
| Native GNOME integration on Zorin OS | Pending |
| Complete cross-desktop integration | Not yet verified |

Isolated tests used redirected XDG directories and mocked system services; they do not replace clean installations or native desktop testing.

## Running

### GTK

```bash
GDK_BACKEND=x11 python3 ~/.local/share/arch-widget/arch-widget-app.py
```

The GTK frontend currently uses the X11 GDK backend for reliable borderless window behavior, including on Wayland sessions.

### KDE Plasma 6

The KDE frontend runs inside a Plasma panel or on the Plasma desktop as a widget; it does not use the GTK launch command.

### GNOME Shell

The GNOME frontend runs as a GNOME Shell Extension, managed through GNOME Extensions or `gnome-extensions`.

## Usage

### GTK controls

| Action | Result |
|---|---|
| Drag header | Reposition widget |
| Click header | Expand / collapse news list |
| Hover ticker | Pause scrolling |
| Click news item | Open article in browser |
| `wiki$` search | Search Arch Wiki inline |
| Right-click | Show quit menu |
| EN / JA toggle | Switch interface language |

KDE and GNOME have separate UI implementations. Their interactions should be validated independently rather than inferred from the GTK features.

## File Structure

### GTK application files

```text
~/.local/share/arch-widget/
├── arch-widget.html       # Main UI
├── arch-widget-app.py     # GTK / WebKitGTK launcher
└── fetch-news.sh          # RSS fetcher
```

### KDE Plasma frontend

```text
plasma/
├── plasmoid/              # Plasma widget package
└── scripts/               # Scripts copied to arch-headlines-plasma/ at installation
```

Plasmoid plugin ID: `org.archlinux.arch-headlines`.

### GNOME frontend

```text
gnome/
├── extension.js
├── metadata.json
├── arch-headlines.svg
├── fetch-news.sh
├── mark-read.sh
└── mark-all-read.sh
```

Extension UUID: `arch-headlines@lifehack890-stack`.

### Desktop integration

The GTK frontend includes the `arch-headlines.desktop` launcher. KDE uses a Plasma widget package; GNOME uses a Shell Extension. Each frontend has its own RSS-fetching service and timer.

## How It Works

### GTK RSS integration

The browser `fetch()` API is subject to cross-origin restrictions when opening local HTML files. The GTK `fetch-news.sh` instead retrieves the Arch Linux RSS feed with `curl` and injects news data into the HTML as the JavaScript variable `ARCH_NEWS_DATA`.

Wiki search uses the [MediaWiki API](https://wiki.archlinux.org/api.php) with `origin=*` to support cross-origin requests.

### GTK network monitoring

The GTK frontend uses `Gio.NetworkMonitor` to detect connectivity changes. Cached news can remain visible while offline; the feed can be refreshed when connectivity returns.

The status indicator's handling of actual network availability versus cached news or fetch failures remains a separate maintenance task. Do not treat every offline/fetch-failure path as fully verified.

### GTK / WebKitGTK integration

GTK 3 and WebKitGTK 4.1 are used for the standalone UI. JavaScript-to-Python event signaling handles external links, window movement, and interactions that cannot be processed entirely inside the WebView.

### KDE and GNOME RSS integration

These frontends use separate JSON news storage and read/unread state tracking:

- `news.json` — fetched news items and unread count
- `state.json` — locally maintained read state

Their interfaces do not use the GTK HTML injection mechanism.

## Known Issues

### GTK — Wayland / X11

The GTK implementation currently requires the X11 GDK backend for reliable borderless window management. This requirement does **not** apply to the native KDE or GNOME frontends.

### GTK — Widget background whitespace

When positioned near the top of the screen, expanding the GTK widget may leave unwanted whitespace below the content. GTK window sizing and WebKit viewport synchronization remain under investigation.

### GTK — Background resize during collapse

Some sizing edge cases remain during collapse, expansion, and reload despite improvements to state preservation.

### GTK — WebKitGTK hardware acceleration warnings

EGL/DRI warnings may appear on systems without full 3D acceleration and do not necessarily prevent launch.

### KDE Plasma 6 — Narrow widget layout

News text can overlap when the widget is resized to a narrow width. Responsive layout changes are pending.

### KDE Plasma 6 — PlasmoidViewer exit crash

A `SIGSEGV` (exit code `139`) was observed when closing `plasmoidviewer` during development. The **crash-report stack trace** involved Qt input-method handling during teardown. The root cause is not established, and this has not been proven to originate from Arch Headlines. Investigation is deferred unless normal Plasma operation reproduces the crash.

### GNOME Shell 46 — Extension reload behavior

During development on GNOME Shell 46 under Wayland, disabling and re-enabling an extension did not always reload updated JavaScript. A full logout/login loaded the changed code in those tests.

See [DEBUGGING.md](DEBUGGING.md) for details.

## Development Status

The GTK frontend provides the original desktop widget. KDE Plasma 6 and GNOME Shell integrations are separate frontends currently undergoing integration testing.

Development priorities:

- Stabilize GTK, KDE Plasma 6, and GNOME implementations
- Verify fresh installation and upgrade behavior
- Test clean and native desktop environments
- Fix frontend-specific layout and interaction issues
- Improve installer reproducibility and dependency documentation
- Prepare AUR packaging after the three frontends are stabilized
- Maintain documentation and debugging records

Passing isolated installer tests does not complete integration testing.

## Verification Environment

### Arch-Hero — Development and regression testing

- OS: Arch Linux
- Desktop: KDE Plasma 6
- Virtualization: VirtualBox
- Role: Development, installer testing, KDE integration and regression testing
- Live KDE upgrade: Verified
- Widget display after session restart: Verified
- Full interaction test coverage: Incomplete

### ThinkPad X260 — Native Zorin OS

- OS: Zorin OS 18.1
- Desktop: GNOME-based
- GNOME Shell version: 46.0 (confirmed on the native machine)
- Role: Native GNOME integration and upgrade testing

Earlier GTK testing was performed on this device. GNOME Shell version compatibility is confirmed, but native GNOME Extension integration using the unified installer is still pending.

### Planned EndeavourOS verification

A clean EndeavourOS environment is planned to test KDE Plasma 6 installation, Auto Detect, initial RSS retrieval, the user timer, panel display, reinstallation, and upgrades. These tests are not yet complete.

### Compatibility scope

Automatic frontend identification, successful package installation, and actual user-interface compatibility are separate verification steps. XFCE and other untested desktops have no general support claim.

## Roadmap

- [ ] Improve GTK 3 frontend compatibility and maintenance
- [ ] Evaluate GTK 4 / native Wayland support long-term
- [ ] Configurable widget position / size
- [ ] Complete GNOME Shell Extension integration tests
- [ ] Complete KDE Plasma 6 integration tests
- [ ] Clean installation test on EndeavourOS
- [ ] Native GNOME integration test on Zorin OS
- [ ] Test additional desktop environments
- [ ] Improve KDE responsive widget layout
- [ ] Finalize unified installer reliability
- [ ] Prepare reproducible AUR packaging
- [x] Remove glassmorphism / Aero styling in favor of a simpler UI

## Uninstallation

**An automated uninstaller has not yet been verified.** These are manual guidelines; remove only the frontend that you intend to uninstall. Installed unit files are normally in `~/.config/systemd/user/` (or `${XDG_CONFIG_HOME}/systemd/user/`).

| Frontend | Service unit | Timer unit |
|---|---|---|
| GTK | `arch-widget-news.service` | `arch-widget-news.timer` |
| KDE Plasma 6 | `arch-headlines-plasma-news.service` | `arch-headlines-plasma-news.timer` |
| GNOME Shell | `arch-headlines-gnome-news.service` | `arch-headlines-gnome-news.timer` |

First, stop and disable the selected frontend's timer. For example, **for KDE only**:

```bash
systemctl --user disable --now arch-headlines-plasma-news.timer
```

Remove the selected frontend's `.service` and `.timer` files from the systemd user directory, then reload the unit definitions:

```bash
systemctl --user daemon-reload
```

Do not delete other frontends' service files or saved state unless you intend to remove them too.

### KDE Plasma 6

Remove the widget from the panel or desktop, then uninstall the Plasmoid package:

```bash
kpackagetool6 --type Plasma/Applet --remove org.archlinux.arch-headlines
```

The three helper scripts and JSON state are located separately under `~/.local/share/arch-headlines-plasma/`. Back up any state you want to retain before removing that directory.

### GNOME Shell

Disable the extension before removing its extension directory:

```bash
gnome-extensions disable arch-headlines@lifehack890-stack
```

The extension files and helper scripts are stored in the extension directory; the JSON news state is under `~/.local/share/arch-headlines-gnome/`. A logout/login may be needed for changes to take effect.

### GTK

After disabling the GTK refresh timer, remove the installed GTK files, desktop launcher, and icon if no longer needed. Back up cached news if you wish to retain it.

## Debugging

Known bugs, suspected causes, previous fixes, and test notes are recorded in [DEBUGGING.md](DEBUGGING.md).

## License

MIT
