#!/usr/bin/env bash
set -euo pipefail

DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/arch-headlines-gnome"
NEWS_FILE="$DATA_DIR/news.json"
STATE_FILE="$DATA_DIR/state.json"
STATE_TMP=""
FEED_TMP=""
NEWS_TMP=""

mkdir -p "$DATA_DIR"
exec 9>"$DATA_DIR/state.lock"
flock -w 10 9
trap 'rm -f -- "$FEED_TMP" "$NEWS_TMP" "$STATE_TMP"' EXIT
FEED_TMP="$(mktemp "$DATA_DIR/.feed.XXXXXXXX")"
NEWS_TMP="$(mktemp "$DATA_DIR/.news.XXXXXXXX")"
if [[ ! -f "$STATE_FILE" ]]; then
    STATE_TMP="$(mktemp "$DATA_DIR/.state.XXXXXXXX")"
fi

curl -fsSL https://archlinux.org/feeds/news/ > "$FEED_TMP"

python3 - "$FEED_TMP" "$STATE_FILE" "$NEWS_TMP" "$STATE_TMP" <<'PY'
import json
import os
import sys
import xml.etree.ElementTree as ET
from urllib.parse import urlsplit

feed_file, state_file, news_file, state_tmp = sys.argv[1:5]

root = ET.parse(feed_file).getroot()

if root.tag != "rss":
    raise ValueError("Invalid RSS: expected <rss> root element")

channel = root.find("channel")
if channel is None:
    raise ValueError("Invalid RSS: missing <channel>")

feed_items = channel.findall("item")
if not feed_items:
    raise ValueError("Invalid RSS: no <item> elements")

items = []

for item in feed_items[:3]:
    title = (item.findtext("title") or "").strip()
    link = (item.findtext("link") or "").strip()
    if not title or not link:
        raise ValueError("Invalid RSS item: missing title or link")

    try:
        parsed = urlsplit(link)
        valid_url = (
            parsed.scheme == "https"
            and parsed.hostname == "archlinux.org"
            and parsed.port in (None, 443)
            and parsed.username is None
            and parsed.password is None
            and parsed.path.startswith("/news/")
            and not any(ord(ch) < 32 or ord(ch) == 127 for ch in link)
        )
    except ValueError:
        valid_url = False

    if not valid_url:
        raise ValueError("Invalid RSS item: unsupported article URL")

    items.append({
        "title": title,
        "link": link,
        "pubDate": item.findtext("pubDate", default="")
    })

current_links = [item["link"] for item in items]

if os.path.exists(state_file):
    with open(state_file, "r", encoding="utf-8") as f:
        state = json.load(f)

    links = state.get("read_links") if isinstance(state, dict) else None
    if not isinstance(links, list) or not all(isinstance(x, str) for x in links):
        raise ValueError("Invalid state.json: read_links must be a list of strings")

    read_links = set(links)
else:
    # First run: treat the current feed as the baseline.
    read_links = set(current_links)

    state = {
        "read_links": list(read_links)
    }

    with open(state_tmp, "w", encoding="utf-8") as f:
        json.dump(state, f, ensure_ascii=False, indent=2)
        f.write("\n")

news = {
    "items": items
}

with open(news_file, "w", encoding="utf-8") as f:
    json.dump(news, f, ensure_ascii=False, indent=2)
PY

mv "$NEWS_TMP" "$NEWS_FILE"
if [[ -n "$STATE_TMP" ]]; then
    mv "$STATE_TMP" "$STATE_FILE"
fi

cat "$NEWS_FILE"
