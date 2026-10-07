#!/usr/bin/env python3
import gi, os, subprocess, sys
gi.require_version("Gtk", "3.0")
gi.require_version("WebKit2", "4.1")
from gi.repository import Gtk, WebKit2, GLib, Gdk, Gio

DATA_DIR = os.path.join(os.environ.get("XDG_DATA_HOME", os.path.expanduser("~/.local/share")), "arch-widget")
HTML_FILE = os.path.join(DATA_DIR, "arch-widget.html")
FETCH_SCRIPT = os.path.join(DATA_DIR, "fetch-news.sh")

def run_fetch():
    try:
        subprocess.run(["bash", FETCH_SCRIPT], check=True, timeout=15)
        return True
    except Exception as e:
        print(f"fetch error: {e}", file=sys.stderr)
        return False

def run_fetch_async(callback):
    def worker():
        result = run_fetch()
        GLib.idle_add(callback, result)

    import threading
    threading.Thread(target=worker, daemon=True).start()

class ArchWidget(Gtk.Window):
    def __init__(self):
        super().__init__(title="Arch-headlines")
        self.set_default_size(500, 88)
        self.set_resizable(False)
        self.set_position(Gtk.WindowPosition.NONE)
        self.move(40, 40)
        self.set_decorated(False)
        self.set_keep_above(True)
        self.set_skip_taskbar_hint(True)
        self.set_skip_pager_hint(True)
        self.set_app_paintable(True)
        self.set_border_width(0)
        screen = self.get_screen()
        visual = screen.get_rgba_visual()
        if visual:
            self.set_visual(visual)
        self.connect("destroy", Gtk.main_quit)
        self.connect("draw", self._on_draw)
        self.add_events(Gdk.EventMask.BUTTON_PRESS_MASK)
        self.connect("button-press-event", self._on_win_press)
        settings = WebKit2.Settings()
        settings.set_enable_javascript(True)
        settings.set_allow_file_access_from_file_urls(True)
        settings.set_allow_universal_access_from_file_urls(True)
        self.webview = WebKit2.WebView()

        self._fetch_in_progress = False
        self.network_monitor = Gio.NetworkMonitor.get_default()
        self.network_monitor.connect(
            "network-changed",
            self._on_network_changed
        )

        transparent = Gdk.RGBA()
        transparent.parse("rgba(0,0,0,0)")
        self.webview.set_background_color(transparent)

        self.webview.set_settings(settings)
        self.webview.connect("notify::title", self._on_title_change)
        self.webview.connect("button-press-event", self._on_win_press)
        self.add(self.webview)
        self.show_all()
        self.fetch_ok = run_fetch()
        self.load_html()
        GLib.timeout_add_seconds(3600, self.refresh)

    def _on_network_changed(self, monitor, available):
        print(f"network changed: {available}", flush=True)

        if not available:
            self.fetch_ok = False
            self.webview.evaluate_javascript(
                "setConnectionStatus(false);",
                -1,
                None,
                None,
                None,
                None,
                None
            )
            return

        if self._fetch_in_progress:
            return

        self._fetch_in_progress = True
        run_fetch_async(self._on_reconnect_fetch_done)

    def _on_reconnect_fetch_done(self, success):
        self._fetch_in_progress = False

        if not self.network_monitor.get_network_available():
            self.fetch_ok = False
            self.webview.evaluate_javascript(
                "setConnectionStatus(false);",
                -1,
                None,
                None,
                None,
                None,
                None
            )
            return False

        self.fetch_ok = success

        if success:
            self.load_html()
        else:
            self.webview.evaluate_javascript(
                "setConnectionStatus(false);",
                -1,
                None,
                None,
                None,
                None,
                None
            )

        return False

    def _on_draw(self, widget, cr):
        cr.set_source_rgba(0, 0, 0, 0)
        cr.set_operator(1)
        cr.paint()

    def _on_win_press(self, widget, event):
        if event.button == 3:
            menu = Gtk.Menu()
            item = Gtk.MenuItem(label="Quit Arch-headlines")
            item.connect("activate", lambda _: Gtk.main_quit())
            menu.append(item)
            menu.show_all()
            menu.popup_at_pointer(event)
            return True
        return False

    def _on_title_change(self, webview, param):
        title = webview.get_title() or ""
        print(f"title: {title}", flush=True)
        if title.startswith("open:"):
            url = title[5:]
            subprocess.Popen(["xdg-open", url])
        elif title == "dragstart":
            # Begin window move using X11 WM
            display = self.get_display()
            seat = display.get_default_seat()
            device = seat.get_pointer()
            self.begin_move_drag(
                1,  # button 1 = left click
                *device.get_position()[1:3],
                Gtk.get_current_event_time()
            )
        elif title.startswith("resize:"):
            try:
                size = title[7:]
                width, height = map(int, size.split("x"))
                self.resize(width, height)
            except (ValueError, TypeError):
                print(f"invalid resize request: {title}", file=sys.stderr)


    def load_html(self):
        fetch_status = "ok" if self.fetch_ok else "error"
        self.webview.load_uri(f"file://{HTML_FILE}#fetch={fetch_status}")

    def refresh(self):
        self.fetch_ok = run_fetch()
        self.load_html()
        return True

if __name__ == "__main__":
    if not os.path.exists(HTML_FILE):
        print(f"error: {HTML_FILE} not found.", file=sys.stderr)
        sys.exit(1)
    app = ArchWidget()
    Gtk.main()
