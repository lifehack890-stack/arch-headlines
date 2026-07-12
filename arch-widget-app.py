#!/usr/bin/env python3
import gi, os, subprocess, sys
gi.require_version("Gtk", "3.0")
gi.require_version("WebKit2", "4.1")
from gi.repository import Gtk, WebKit2, GLib, Gdk

DATA_DIR = os.path.join(os.environ.get("XDG_DATA_HOME", os.path.expanduser("~/.local/share")), "arch-widget")
HTML_FILE = os.path.join(DATA_DIR, "arch-widget.html")
FETCH_SCRIPT = os.path.join(DATA_DIR, "fetch-news.sh")

def run_fetch():
    try:
        subprocess.run(["bash", FETCH_SCRIPT], check=True, timeout=15)
    except Exception as e:
        print(f"fetch error: {e}", file=sys.stderr)

class ArchWidget(Gtk.Window):
    def __init__(self):
        super().__init__(title="arch-headlines")
        self.set_default_size(500, 88)
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

        # Drag state
        self._dragging = False
        self._drag_x = 0
        self._drag_y = 0
        self._win_x = 40
        self._win_y = 40
        self.add_events(
            Gdk.EventMask.BUTTON_PRESS_MASK |
            Gdk.EventMask.BUTTON_RELEASE_MASK |
            Gdk.EventMask.POINTER_MOTION_MASK
        )
        self.connect("button-press-event", self._on_win_press)
        self.connect("button-release-event", self._on_win_release)
        self.connect("motion-notify-event", self._on_motion)

        settings = WebKit2.Settings()
        settings.set_enable_javascript(True)
        settings.set_allow_file_access_from_file_urls(True)
        settings.set_allow_universal_access_from_file_urls(True)

        self.webview = WebKit2.WebView()
        self.webview.set_settings(settings)
        self.webview.connect("notify::title", self._on_title_change)
        self.webview.connect("decide-policy", self._on_policy)
        self.webview.connect("context-menu", self._on_context_menu)

        self.add(self.webview)
        self.show_all()

        run_fetch()
        self.load_html()
        GLib.timeout_add_seconds(3600, self.refresh)

    def _on_policy(self, webview, decision, decision_type):
        if decision_type == WebKit2.PolicyDecisionType.NAVIGATION_ACTION:
            action = decision.get_navigation_action()
            uri = action.get_request().get_uri()
            if uri.startswith("http"):
                subprocess.Popen(["xdg-open", uri])
                decision.ignore()
                return True
        return False

    def _on_context_menu(self, webview, menu, event, hit):
        # Replace context menu with quit option
        menu.remove_all()
        item = WebKit2.ContextMenuItem.new_from_stock_action(WebKit2.ContextMenuAction.NO_ACTION)
        quit_item = Gtk.MenuItem(label="Quit arch-headlines")
        quit_item.connect("activate", lambda _: Gtk.main_quit())
        menu.append(WebKit2.ContextMenuItem.new_separator())
        return False

    def _on_draw(self, widget, cr):
        cr.set_source_rgba(0, 0, 0, 0)
        cr.set_operator(1)
        cr.paint()

    def _on_win_press(self, widget, event):
        if event.button == 3:
            # Right-click quit menu
            menu = Gtk.Menu()
            item = Gtk.MenuItem(label="Quit arch-headlines")
            item.connect("activate", lambda _: Gtk.main_quit())
            menu.append(item)
            menu.show_all()
            menu.popup_at_pointer(event)
            return True
        if event.button == 1:
            self._dragging = True
            self._drag_x = event.x_root
            self._drag_y = event.y_root
            self._win_x, self._win_y = self.get_position()

    def _on_win_release(self, widget, event):
        self._dragging = False

    def _on_motion(self, widget, event):
        if self._dragging and (event.state & Gdk.ModifierType.BUTTON1_MASK):
            dx = event.x_root - self._drag_x
            dy = event.y_root - self._drag_y
            # Only move if dragged more than 5px (to allow clicks)
            if abs(dx) > 5 or abs(dy) > 5:
                self.move(int(self._win_x + dx), int(self._win_y + dy))

    def _on_title_change(self, webview, param):
        title = webview.get_title() or ""
        if title == "expanded":
            self.resize(500, 700)
        elif title == "collapsed":
            self.resize(500, 88)

    def load_html(self):
        self.webview.load_uri(f"file://{HTML_FILE}")

    def refresh(self):
        run_fetch()
        self.load_html()
        return True

if __name__ == "__main__":
    if not os.path.exists(HTML_FILE):
        print(f"error: {HTML_FILE} not found.", file=sys.stderr)
        sys.exit(1)
    app = ArchWidget()
    Gtk.main()
