import Pango from 'gi://Pango';
import Clutter from 'gi://Clutter';
import GLib from 'gi://GLib';
import Gio from 'gi://Gio';
import St from 'gi://St';

import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import * as PanelMenu from 'resource:///org/gnome/shell/ui/panelMenu.js';
import * as PopupMenu from 'resource:///org/gnome/shell/ui/popupMenu.js';

export default class ArchHeadlinesExtension extends Extension {
    enable() {
        this._indicator = new PanelMenu.Button(
            0.0,
            'Arch Headlines',
            false
        );

        const {data, items, loadFailed} = this._loadData();

        const iconFile = this.dir.get_child('arch-headlines.svg');

        const icon = new St.Icon({
            gicon: new Gio.FileIcon({file: iconFile}),
            style_class: 'system-status-icon',
        });

        this._iconStack = new St.Widget({
            layout_manager: new Clutter.BinLayout(),
        });

        this._iconStack.add_child(icon);

        this._updateBadge(data.unread_count);

        this._indicator.add_child(this._iconStack);

        this._renderMenu(data, items, loadFailed);

        this._indicator.menu.connect('open-state-changed', (menu, isOpen) => {
            if (!isOpen)
                return;

            const {
                data: refreshedData,
                items: refreshedItems,
                loadFailed: refreshedLoadFailed,
            } = this._loadData();

            this._updateBadge(refreshedData.unread_count);
            this._renderMenu(
                refreshedData,
                refreshedItems,
                refreshedLoadFailed
            );
        });

        Main.panel.addToStatusArea(
            this.uuid,
            this._indicator
        );
    }

    _renderMenu(data, items, loadFailed) {
        this._indicator.menu.removeAll();

        const articleDots = [];

        for (const article of items) {
            const item = new PopupMenu.PopupBaseMenuItem();

            const dot = new St.Widget({
                style: `
                    background-color: ${article.unread ? '#1793D1' : 'transparent'};
                    border-radius: 4px;
                    width: 8px;
                    height: 8px;
                    margin-right: 8px;
                `,
                y_align: Clutter.ActorAlign.CENTER,
            });

            articleDots.push({article, dot});

            const title = new St.Label({
                text: article.title,
                y_align: Clutter.ActorAlign.CENTER,
                width: 500,
            });

            title.clutter_text.set_single_line_mode(true);
            title.clutter_text.set_ellipsize(Pango.EllipsizeMode.END);

            item.add_child(dot);
            item.add_child(title);

            item.connect('activate', () => {
                Gio.AppInfo.launch_default_for_uri(
                    article.link,
                    null
                );

                if (!article.unread || article.markingRead)
                    return;

                article.markingRead = true;

                const scriptPath = this.dir.get_child('mark-read.sh').get_path();

                const proc = Gio.Subprocess.new(
                    [scriptPath, article.link],
                    Gio.SubprocessFlags.STDOUT_PIPE |
                    Gio.SubprocessFlags.STDERR_PIPE
                );

                proc.wait_check_async(null, (process, result) => {
                    try {
                        process.wait_check_finish(result);
                        article.unread = false;
                        dot.opacity = 0;

                        data.unread_count = Math.max(
                            0,
                            data.unread_count - 1
                        );

                        this._updateBadge(data.unread_count);
                    } catch (e) {
                        console.error(`Arch Headlines mark-read failed: ${e}`);
                    } finally {
                        article.markingRead = false;
                    }
                });
            });

            this._indicator.menu.addMenuItem(item);
        }

        if (loadFailed) {
            const errorItem = new PopupMenu.PopupMenuItem(
                'Failed to load Arch news'
            );
            errorItem.setSensitive(false);
            this._indicator.menu.addMenuItem(errorItem);
        } else if (items.length === 0) {
            const emptyItem = new PopupMenu.PopupMenuItem(
                'No Arch news available'
            );
            emptyItem.setSensitive(false);
            this._indicator.menu.addMenuItem(emptyItem);
        }

        this._indicator.menu.addMenuItem(
            new PopupMenu.PopupSeparatorMenuItem()
        );

        const markAllReadItem = new PopupMenu.PopupMenuItem('Mark all as read');

        markAllReadItem.connect('activate', () => {
            console.log('Arch Headlines: mark-all-read clicked');

            const scriptPath = this.dir.get_child('mark-all-read.sh').get_path();

            const proc = Gio.Subprocess.new(
                [scriptPath],
                Gio.SubprocessFlags.STDOUT_PIPE |
                Gio.SubprocessFlags.STDERR_PIPE
            );

            proc.wait_check_async(null, (process, result) => {
                try {
                    process.wait_check_finish(result);
                    console.log('Arch Headlines: mark-all-read finished');

                    for (const {article, dot} of articleDots) {
                        article.unread = false;
                        dot.opacity = 0;
                    }

                    data.unread_count = 0;
                    this._updateBadge(0);
                } catch (e) {
                    console.error(`Arch Headlines mark-all-read failed: ${e}`);
                }
            });
        });

        this._indicator.menu.addMenuItem(markAllReadItem);
    }

    _updateBadge(count) {
        this._badge?.destroy();
        this._badge = null;
        this._badgeLabel = null;

        if (count <= 0)
            return;

        const badgeText = count > 99 ? '99+' : String(count);

        const badge = new St.Widget({
            x_align: Clutter.ActorAlign.END,
            y_align: Clutter.ActorAlign.END,
            style: `
                background-color: #E81123;
                border-radius: 8px;
                min-width: 14px;
                min-height: 14px;
            `,
            layout_manager: new Clutter.BinLayout(),
        });

        const badgeLabel = new St.Label({
            text: badgeText,
            x_align: Clutter.ActorAlign.CENTER,
            y_align: Clutter.ActorAlign.CENTER,
            x_expand: true,
            y_expand: true,
            style: `
                color: white;
                font-size: 9px;
                font-weight: bold;
            `,
        });

        badgeLabel.clutter_text.set_line_alignment(Pango.Alignment.CENTER);

        badge.add_child(badgeLabel);
        this._iconStack.add_child(badge);

        this._badge = badge;
        this._badgeLabel = badgeLabel;
    }

    _loadData() {
        const newsFile = Gio.File.new_for_path(
            `${GLib.get_user_data_dir()}/arch-headlines-gnome/news.json`
        );

        const stateFile = Gio.File.new_for_path(
            `${GLib.get_user_data_dir()}/arch-headlines-gnome/state.json`
        );

        let data = {
            items: [],
            unread_count: 0,
        };
        let loadFailed = false;

        try {
            const [, contents] = newsFile.load_contents(null);
            const text = new TextDecoder().decode(contents);
            data = JSON.parse(text);
        } catch (e) {
            loadFailed = true;
            console.error(`Arch Headlines: ${e}`);
        }

        const items = Array.isArray(data.items) ? data.items : [];

        let readLinks = new Set();

        try {
            const [, stateContents] = stateFile.load_contents(null);
            const stateText = new TextDecoder().decode(stateContents);
            const state = JSON.parse(stateText);

            if (Array.isArray(state.read_links))
                readLinks = new Set(state.read_links);
        } catch (e) {
            console.error(`Arch Headlines state: ${e}`);
        }

        for (const article of items)
            article.unread = !readLinks.has(article.link);

        data.unread_count = items.filter(article => article.unread).length;

        return {data, items, loadFailed};
    }

    disable() {
        this._indicator?.destroy();
        this._indicator = null;
    }
}
