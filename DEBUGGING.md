# arch-headlines — Debug Log

## Known Bugs & Status

### [Fixed] v0.2 — Left click not opening links

**Root cause:**
`button-press-event` was connected to both the GTK window and WebView,
causing left-click events to be intercepted by drag movement logic before reaching the WebView.

**Fix:**
- Removed drag movement feature (`_on_press` / `_on_motion` deleted)
- Left-click fully delegated to WebView
- Links now intercepted via JS `document.addEventListener('click')` → `document.title = 'open:URL'` → Python calls `xdg-open`
- Right-click quit menu retained at window level

**Verified on:**
- Zorin OS / X11 session (`GDK_BACKEND=x11`)
- ThinkPad X260

---

### [Open] Window titlebar not hidden on Wayland

**Root cause:**
On Wayland, window decorations are managed by the compositor, so `set_decorated(False)` has no effect.

**Workaround:**
Force X11 backend with `GDK_BACKEND=x11`.

**Proposed fix:**
- Port to GTK4 + libadwaita (native Wayland support)
- Or use Wayland protocol hints directly

---

### [Open] Drag to reposition widget

**Root cause:**
Right-click drag conflicted with WebKit's context menu handler.
`WebKit2.ContextMenuItem.new_with_custom_menu_item` is not available in WebKit2GTK 4.1,
causing the app to crash silently on startup when included.

**Proposed fix:**
- Implement drag on a thin GTK overlay header outside the WebView
- Or use `GDK_BACKEND=x11` + `begin_move_drag()`

---

### [By design] Transparent background

WebView background blends with the desktop wallpaper due to GTK `set_app_paintable(True)` + Cairo transparency.
This is intentional — the widget is designed to sit on top of the wallpaper.

---

## Debug Procedure (Wayland vs X11)

1. Log out of Zorin
2. At the login screen, click the gear icon and select **"Zorin Desktop on Xorg"**
3. Log in and launch without `GDK_BACKEND=x11`
4. Verify behavior
5. Switch back to Wayland session and compare with `GDK_BACKEND=x11`

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

- [ ] Fix titlebar on Wayland (GTK4 port)
- [ ] Restore drag-to-move (non-conflicting implementation)
- [ ] Glassmorphism / Aero style (backdrop-filter via compositor)
- [ ] Flatpak packaging
- [ ] AUR package
