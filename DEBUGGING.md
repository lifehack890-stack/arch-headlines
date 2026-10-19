# arch-headlines — Debug Log

This document records known bugs, their root causes, fixes, and current
limitations of arch-headlines.

---

## Fixed Bugs

### [Fixed] v0.2 — Left-click links not opening

**Root cause:**

`button-press-event` handling was connected to both the GTK window and
WebView. The previous GTK-level drag implementation intercepted left-click
events before they could reach the WebView.

**Fix:**

- Removed the original GTK-level drag implementation
  (`_on_press` / `_on_motion`).
- Left-click interaction was delegated to the WebView.
- Links are intercepted through JavaScript:
  `document.addEventListener('click')`
- The clicked URL is passed to Python through:
  `document.title = 'open:URL'`
- Python launches the URL using `xdg-open`.

**Note:**

The original GTK-level drag implementation was intentionally removed in
v0.2 because it conflicted with normal WebView click handling.

**Verified on:**

- Zorin OS
- X11 session
- ThinkPad X260

---

### [Fixed] v0.3 — Right-click quit menu not appearing

**Root cause:**

WebKit's default context menu was handling right-click events before the
GTK window-level handler could display the application's quit menu.

**Fix:**

- Added explicit right-click handling for the WebView.
- Right-click events are passed to the GTK-level menu handler.
- Right-clicking anywhere on the widget now provides the
  `Quit arch-headlines` option.

**Note:**

The right-click handling introduced in v0.3 is separate from the
left-click drag implementation removed in v0.2.

---

### [Fixed] v0.3 — Widget could not be repositioned

**Root cause:**

The original GTK-level drag implementation was removed in v0.2 because it
interfered with WebView click events. As a result, the widget temporarily
had no repositioning mechanism.

**Fix:**

A new header-based drag implementation was introduced in v0.3:

- Header `mousedown` is detected by the WebView.
- JavaScript sends `document.title = 'dragstart'`.
- Python receives the event and calls GTK's `begin_move_drag()`.
- A 5-pixel movement threshold distinguishes clicking from dragging.
- Movement under 5 pixels is treated as a normal click.
- Movement over 5 pixels starts window repositioning.
- Normal WebView links remain unaffected.

**Implementation note:**

This is a new drag implementation and is not the GTK-level
`_on_press` / `_on_motion` implementation removed in v0.2.

---

### [Fixed] v0.3 — Titlebar visible under Wayland

**Root cause:**

`set_decorated(False)` does not reliably remove window decorations under
some Wayland compositors.

**Fix:**

The current implementation avoids the unwanted titlebar without requiring
a GTK4 port.

**Current limitation:**

The application currently requires the X11 GDK backend for its window
management behavior.

---

### [Fixed] v0.4 — EN/JA toggle caused widget collapse

**Root cause:**

Clicking the language toggle generated mouse events that propagated to the
widget's expand/collapse handler.

**Fix:**

- Added `onmousedown` handling to the language toggle.
- Added `onmouseup` handling to the language toggle.
- Used `stopPropagation` to prevent the toggle events from reaching the
  widget's collapse/expand handler.
- Language switching no longer triggers an unintended collapse.

---

### [Fixed] v0.5 — UI overhaul and layout streamlining

**Changes:**

- Redesigned the titlebar and ticker layout to reduce the widget's
  vertical footprint.
- Integrated the EN/JA language toggle into the titlebar.
- Adjusted spacing and font hierarchy.
- Optimized the search input layout.
- Reworked layout calculations and component hierarchy to reduce unwanted
  whitespace during expand/collapse transitions.

---

### [Fixed] v0.6 — KDE application launcher icon not displayed

**Root cause:**

The KDE application launcher did not reliably resolve the application's
custom icon when the desktop entry referenced the icon using a direct
file path.

The previous desktop entry used:

```ini
Icon=%h/.local/share/arch-widget/arch-headlines.png
```

KDE Plasma's icon theme lookup works more reliably when the desktop entry
uses an icon name and the icon is installed into the active icon theme.

**Fix:**

- Added `arch-headlines.svg` to the repository.
- Installed the SVG into the local Breeze icon theme:

```text
~/.local/share/icons/breeze/apps/scalable/arch-headlines.svg
```

- Updated the desktop entry to use:

```ini
Icon=arch-headlines
```

- Refreshed the KDE application cache:

```bash
kbuildsycoca6 --noincremental
```

- Updated `install.sh` to install the SVG icon automatically.

**Result:**

The `arch-headlines` icon is now displayed correctly in the KDE
application launcher.

---

### [Fixed] v0.7 — WebView background was not transparent

**Root cause:**

The WebView background was not explicitly configured as transparent.
As a result, the WebView could render its own opaque background instead of
allowing the transparent GTK window background to show through.

**Fix:**

- Added an explicit transparent `Gdk.RGBA` background to the WebView.
- Applied the transparent background using
  `WebKit2.WebView.set_background_color()`.
- Retained the existing GTK RGBA visual and transparent window drawing
  behavior.

**Result:**

The WebView background is now transparent, allowing the widget's existing
transparent/semi-transparent appearance to be displayed correctly.

**Current limitation:**

This change provides WebView transparency but does not provide guaranteed
compositor-level backdrop blur.

---

## Open Bugs

### [Open] Background does not fully follow widget size when collapsed

**Description:**

The transparent/glass-style background does not always resize correctly
when the widget is collapsed.

**Suspected cause:**

GTK window resizing and WebKit content repainting are not always
synchronized during the expand/collapse transition.

**Current status:**

Under investigation.

**Possible solution:**

Further investigation of GTK window resize events and WebKit viewport
recalculation is required. A future implementation may explicitly
synchronize the GTK window size with the WebView content size.

---

### [Open] Widget background whitespace when positioned near the top of the screen

**Description:**

When the widget is positioned near the top of the screen, expanding the
widget can result in unwanted whitespace below the visible content.

**Suspected cause:**

A mismatch between the GTK window height and the WebKit content viewport.

The current body CSS previously used:

`min-height: 100vh`

This can cause WebKit to request a full viewport height even when the
actual widget content is smaller.

**Previous attempt:**

The following CSS changes were tested:

- `min-height: 0`
- `max-height: none`

These changes resulted in additional layout regressions and were therefore
not retained.

**Current status:**

Under investigation.

**Possible solution:**

Investigate the interaction between:

- GTK window resizing
- WebKit viewport size
- CSS viewport units
- expand/collapse state changes

The final implementation should allow the WebView content to determine the
required widget height without forcing a full viewport height.

---

### [Open] KDE Plasma 6 — News text overlaps in narrow widgets

**Description:**

News text can overlap when the Plasma panel widget is narrow.
The problem was observed in the live Arch-Hero KDE Plasma session.

**Current status:**

Reproducible layout issue; responsive sizing work is pending. The widget
can display news after a session restart, but that does not resolve this issue.

**Planned verification:**

Test compact and expanded representations at several panel widths, then
repeat after a logout/login. This issue is separate from GTK window sizing.

---

### [Deferred] KDE plasmoidviewer — SIGSEGV on exit (code 139)

**Observation:**

A segmentation fault was reported while closing `plasmoidviewer` during
KDE Plasma 6 development testing. The crash-report stack trace involved
Qt input-method handling during object teardown.

**Uncertainty:**

This does **not** establish that arch-headlines caused the crash. The root
cause remains undetermined; a viewer shutdown failure is not proof that
the installed widget crashes in normal `plasmashell` operation.

**Current status:**

Investigation is deferred unless the problem is reproduced during normal
Plasma operation. Do not describe this as fixed or exonerated.

---

## Known Limitations

### [Known Limitation] Glassmorphism blur is compositor-dependent

True CSS `backdrop-filter: blur()` depends on compositor support and cannot
be guaranteed across all Linux desktop environments.

Known environments include:

- **GNOME** — may require Blur my Shell or similar compositor support
- **KDE Plasma** — may require KWin configuration or scripts
- **Hyprland** — blur can be configured through compositor settings
- **Sway** — does not provide the required blur effect in the same way

**Current workaround:**

The application uses a transparent WebView background with a
semi-transparent dark UI background when true backdrop blur is unavailable.

**Future options:**

- Per-compositor integration
- GTK4 migration and native compositor integration
- Retain the current transparent/semi-transparent fallback

This is considered an environment-dependent limitation rather than a
core application bug.

---

### [Known Limitation] GTK frontend requires the X11 GDK backend

The standalone GTK frontend is launched using the X11 GDK backend:

```bash
GDK_BACKEND=x11 python3 ~/.local/share/arch-widget/arch-widget-app.py
```

This is currently required for the GTK application's window management and
decoration behavior under Wayland environments. It is not a requirement of
the native KDE Plasma or GNOME Shell frontends.

A future version may improve native Wayland support.

---

## Launch Commands (GTK frontend)

### Standard launch

```bash
GDK_BACKEND=x11 python3 ~/.local/share/arch-widget/arch-widget-app.py
```

### Debug launch

```bash
GDK_BACKEND=x11 python3 ~/.local/share/arch-widget/arch-widget-app.py 2>&1 | tee /tmp/arch-headlines.log
```

The debug command captures standard output and error output to:

```text
/tmp/arch-headlines.log
```

---

## Development Notes

The standalone GTK frontend uses GTK and WebKitGTK for its desktop UI.

Interaction between the WebView and GTK window is handled through
JavaScript-to-Python event signaling where necessary. This is used for
operations such as:

- Opening external links
- Starting window movement
- Handling interactions that must be processed by GTK rather than the
  WebView

Changes to mouse event handling should be tested carefully because GTK
and WebKit can both receive the same pointer events.

When modifying expand/collapse behavior, test the widget both near the
top of the screen and in the middle of the desktop to detect viewport
and window-sizing issues.

---

## Git / Repository Troubleshooting

### Local branch is behind `origin/main`

If the remote repository contains commits that are not present locally,
check the repository state first:

```bash
git status
git log --oneline --decorate -5
```

If local changes need to be preserved:

```bash
git stash push -u -m "local changes"
```

Update the branch:

```bash
git pull --ff-only
```

Restore the local changes:

```bash
git stash pop
```

After restoring, verify the working tree:

```bash
git status
git diff
```

Resolve any conflicts manually before committing.

---

### GitHub HTTPS push authentication

GitHub does not accept account passwords for Git operations over HTTPS.

A Personal Access Token (PAT) is required for HTTPS pushes.

For a fine-grained PAT, repository access should be limited to the
required repository.

The token must have the repository permission required to push commits,
including:

```text
Contents: Read and write
```

Repository metadata access is also required by GitHub.

Push the intended branch explicitly (for example, `main` after merging,
or `hardening` when publishing that development branch). Do not assume
that the current branch should be pushed to `main`.

When Git asks for credentials:

```text
Username: GitHub username
Password: Personal Access Token
```

**Never store or document the actual token value in this repository.**

If authentication fails with:

```text
Password authentication is not supported for Git operations.
```

verify that Git is using the PAT rather than the GitHub account password.

---

## Verification Environment

### Arch-Hero — Arch Linux / KDE Plasma 6 (VirtualBox)

- Development and integration-test environment for the unified installer.
- Isolated GTK, KDE, and GNOME installer tests used redirected XDG paths and
  mocked external services; they did not prove native desktop compatibility.
- Live KDE Plasma widget upgrade using the unified installer: succeeded.
- The KDE refresh timer was enabled and active (waiting).
- The installed widget displayed news after a logout/login.
- Narrow panel layout and some click/read-state interactions remain unverified
  or unresolved; successful installation is not full integration sign-off.

### ThinkPad X260 — Zorin OS 18.1 (native)

- GNOME-based desktop; `gnome-shell --version` returned `GNOME Shell 46.0`.
- Earlier GTK/X11 tests were performed on this hardware.
- The prior hardware problem has been resolved; the machine is operational.
- GNOME Shell version compatibility is confirmed, but unified-installer
  native GNOME Extension installation/upgrade tests are **pending**.

### Planned clean install — EndeavourOS / KDE Plasma 6

Clean installation, automatic detection, initial fetch, systemd user timer,
widget display, reinstall and upgrade tests are **pending**.

Do not infer support for XFCE or other desktop environments from the
installer's fallback classification. Cross-desktop compatibility is not yet
established.

---

## GNOME Shell 46 / Wayland: extension changes may require logout/login

During GNOME Shell 46 testing on Wayland, disabling and re-enabling an extension with `gnome-extensions` did not always reload updated JavaScript module code.

Observed behavior:

- Updated `extension.js` was correctly copied to the extension directory.
- `gnome-extensions disable` followed by `gnome-extensions enable` sometimes continued running the previously loaded code.
- Newly added signal handlers and debug logging did not take effect.
- Logging out and logging back in forced GNOME Shell to reload the extension and resolved the issue.

When debugging GNOME Shell extensions on Wayland, if updated code appears not to run despite the deployed file being correct, perform a full logout/login before assuming the extension logic is broken.

Useful verification:

`journalctl --user -b --no-pager | grep 'Arch Headlines'`

This behavior was observed during development on GNOME Shell 46.0 under Wayland.

---

## Unified Installer Verification — 2026-10-19

The unified `install.sh` supports `GTK`, `KDE Plasma 6`, and `GNOME Shell`.
Its interactive menu contains Auto Detect, GTK, KDE, GNOME, and Cancel.
For isolated testing it accepts `ARCH_HEADLINES_FRONTEND` values:
`auto`, `gtk`, `kde`, `gnome`, and `cancel`.

### Isolated sandbox / mock tests

| Test | Observed result |
|---|---|
| Interactive choices 1–5 | Expected outcomes passed |
| Invalid choice 6 | Rejected with exit code 1 |
| Auto Detect: KDE | Classified as KDE |
| Auto Detect: GNOME / Zorin | Classified as GNOME |
| Auto Detect: XFCE | Fell back to GTK; **not** evidence of XFCE support |
| GTK initial installation | Passed with mocked services |
| KDE installation / upgrade | Both passed with mocked package tooling |
| GNOME initial installation | Passed with mocked services |
| Cancel selection | Exited without installing |
| Unsupported `$` in XDG data path | Rejected during preflight |

**Limits:** These tests used redirected XDG directories, mocked `systemctl`,
KDE package tooling and GNOME version reporting, and test news data. They
do not establish a successful clean OS installation, working GNOME Shell
extension, or full panel interaction behavior.

### Live Arch-Hero / KDE tests

- Installed/upgraded the KDE Plasmoid with the unified installer using
  `ARCH_HEADLINES_FRONTEND=kde`.
- The installed `main.qml` was compared with the working-tree source and
  reported as matching.
- The `arch-headlines-plasma-news.timer` was loaded, enabled and active
  (waiting), and an initial `news.json` was generated.
- The installed widget displayed news after logout/login.
- The responsive text-overlap defect remains open; interaction and read-state
  verification is incomplete.
- A backup was taken before the live upgrade.

### Outstanding tests / documentation maintenance

- **EndeavourOS (new VM):** clean KDE install, timer, UI, reinstall and upgrade.
- **Zorin OS 18.1 on X260:** native GNOME Shell 46 extension install,
  activation, fetch, read/unread actions, and upgrade.
- **KDE runtime:** confirm link opening, mark-read and mark-all-read actions,
  and behavior at narrow panel widths.
- **GTK:** handle the separate `.dot` offline/fetch-failure status issue;
  do not conflate cached-news availability with live connectivity.
- **Installer:** the initial fetch is best-effort. If it fails, the installer
  warns and continues; `systemctl --user` itself is a required preflight.
- **KDE runtime dependency:** the Plasma5Support QML module is required by
  the QML import. The current installer warns if it is not detected.
- **Release:** update README development-branch notes when the unified
  installer is actually merged/published on `main`.

### Installed user-unit names

| Frontend | Service | Timer |
|---|---|---|
| GTK | `arch-widget-news.service` | `arch-widget-news.timer` |
| KDE Plasma 6 | `arch-headlines-plasma-news.service` | `arch-headlines-plasma-news.timer` |
| GNOME Shell | `arch-headlines-gnome-news.service` | `arch-headlines-gnome-news.timer` |

KDE helper scripts `fetch-news.sh`, `mark-read.sh`, and `mark-all-read.sh`
are installed under `$XDG_DATA_HOME/arch-headlines-plasma/` (default
`~/.local/share/arch-headlines-plasma/`), **not** inside the installed
Plasmoid package directory.
