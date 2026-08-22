# arch-headlines — Debug Log

## Fixed Bugs

### [Fixed] v0.2 — Left click not opening links

**Root cause:**
`button-press-event` was connected to both the GTK window and WebView,
causing left-click events to be intercepted by drag movement logic before reaching the WebView.

**Fix:**
- Removed drag movement feature (`_on_press` / `_on_motion` deleted)
- Left-click fully delegated to WebView
- Links intercepted via JS `document.addEventListener('click')` → `document.title = 'open:URL'` → Python calls `xdg-open`
- Right-click quit menu retained at window level

**Verified on:** Zorin OS / X11 session (`GDK_BACKEND=x11`) / ThinkPad X260

---

### [Fixed] v0.3 — Right-click quit menu not appearing

**Root cause:**
WebKit's default context menu was intercepting right-click before the GTK window handler.

**Fix:**
- Connected `button-press-event` to both GTK window and WebView
- Right-click anywhere on widget now shows "Quit arch-headlines" menu

---

### [Fixed] v0.3 — Widget could not be repositioned

**Root cause:**
No drag implementation existed after removing the conflicting drag logic in v0.2.

**Fix:**
- Header `mousedown` → `document.title = 'dragstart'` → Python calls `begin_move_drag()`
- 5px threshold: under 5px = click (expand/collapse), over 5px = drag (reposition)
- Left-click links unaffected

---

### [Fixed] v0.3 — Titlebar visible on Wayland

**Root cause:**
`set_decorated(False)` has no effect on some Wayland compositors.

**Fix:**
Resolved without GTK4 port — titlebar no longer appears in current build.
`GDK_BACKEND=x11` still required for launch.

---

## Open Bugs

### [Open] EN/JA toggle causes widget to collapse

Switching language while widget is expanded causes it to collapse unexpectedly.

**Suspected cause:**
Re-render during language switch triggers a `document.title` change that Python
interprets as `'collapsed'`.

**Debug steps:**
```bash
GDK_BACKEND=x11 python3 ~/.local/share/arch-widget/arch-widget-app.py 2>&1
```
Expand widget, switch EN/JA, check `title:` output in terminal.

---

### [Open] Background not following widget on collapse

Glassmorphism/transparent background does not resize correctly when widget collapses.

**Suspected cause:**
GTK window resize and WebView repaint are not synchronized.

---

### [Open] Glassmorphism effect (compositor-dependent)

True `backdrop-filter: blur()` requires compositor support:
- GNOME → Blur my Shell extension
- KDE → KWin Rules/scripts
- Hyprland → `decoration:blur` in config
- Sway → not supported

Current workaround: semi-transparent dark background via CSS.
True blur requires per-compositor implementation or GTK4 port.

### [Fixed] v0.4 — EN/JA toggle causes widget to collapse

Fixed by adding onmousedown/onmouseup stopPropagation to lang-toggle div,
preventing mouseup from triggering collapsed state on language switch.
---

### [Open] Widget background whitespace on upper-screen placement

When widget is placed near top of screen, white area appears below widget on expand.
Root cause: GTK window height and WebKit content height mismatch.
min-height:100vh in body CSS causes WebKit to request full viewport height.
Partial fix attempted (min-height:0, max-height:none) caused worse regression.
Needs further investigation.

## Launch Commands

```bash
# Standard launch (X11 backend required on Wayland)
GDK_BACKEND=x11 python3 ~/.local/share/arch-widget/arch-widget-app.py

# Debug launch with log output
GDK_BACKEND=x11 python3 ~/.local/share/arch-widget/arch-widget-app.py 2>&1 | tee /tmp/arch-headlines.log
```

## Manual Update

```bash
# Force news refresh
bash ~/.local/share/arch-widget/fetch-news.sh

# Check systemd timer
systemctl --user status arch-widget-news.timer
```

## Roadmap

- [ ] Fix EN/JA toggle collapse bug
- [ ] Fix background tracking on collapse
- [ ] Glassmorphism (compositor-agnostic solution)
- [ ] Drag-to-reposition polish
- [ ] Flatpak packaging
- [ ] AUR package
- [ ] GTK4 port (Wayland native)
