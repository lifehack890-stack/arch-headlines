#!/usr/bin/env bash
set -euo pipefail

DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/arch-headlines-gnome"
NEWS_FILE="$DATA_DIR/news.json"
STATE_FILE="$DATA_DIR/state.json"
FEED_TMP="$(mktemp)"
NEWS_TMP="${NEWS_FILE}.tmp"

mkdir -p "$DATA_DIR"
trap 'rm -f "$FEED_TMP" "$NEWS_TMP"' EXIT

curl -fsSL https://archlinux.org/feeds/news/ > "$FEED_TMP"

python3 - "$FEED_TMP" "$STATE_FILE" "$NEWS_TMP" <<'PY'
import json
import os
import sys
import xml.etree.ElementTree as ET

feed_file, state_file, news_file = sys.argv[1:4]

root = ET.parse(feed_file).getroot()

items = []

for item in root.findall("./channel/item")[:3]:
    items.append({
        "title": item.findtext("title", default=""),
        "link": item.findtext("link", default=""),
        "pubDate": item.findtext("pubDate", default="")
    })

current_links = [item["link"] for item in items]

if os.path.exists(state_file):
    with open(state_file, "r", encoding="utf-8") as f:
        state = json.load(f)

    read_links = set(state.get("read_links", []))
else:
    # First run: treat the current feed as the baseline.
    read_links = set(current_links)

    state = {
        "read_links": list(read_links)
    }

    with open(state_file, "w", encoding="utf-8") as f:
        json.dump(state, f, ensure_ascii=False, indent=2)

news = {
    "items": items
}

with open(news_file, "w", encoding="utf-8") as f:
    json.dump(news, f, ensure_ascii=False, indent=2)
PY

mv "$NEWS_TMP" "$NEWS_FILE"

cat "$NEWS_FILE"
