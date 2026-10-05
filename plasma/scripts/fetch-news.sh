#!/bin/bash
set -euo pipefail

DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/arch-headlines-plasma"
FEED_URL="https://archlinux.org/feeds/news/"
OUTPUT_FILE="$DATA_DIR/news.json"
TMP_FILE="$DATA_DIR/news.json.tmp"
STATE_FILE="$DATA_DIR/state.json"

mkdir -p "$DATA_DIR"

XML=$(curl -fsS --max-time 10 "$FEED_URL")

python3 - "$TMP_FILE" "$STATE_FILE" <<PYEOF
import sys
import os
import json
import datetime
import xml.etree.ElementTree as ET
from email.utils import parsedate_to_datetime

output_file = sys.argv[1]
state_file = sys.argv[2]

xml = r"""$XML"""
root = ET.fromstring(xml)

ns = {
    "dc": "http://purl.org/dc/elements/1.1/"
}

items = []

for item in root.findall(".//item")[:12]:
    title = item.findtext("title", "").strip()
    link = item.findtext("link", "").strip()
    pub = item.findtext("pubDate", "").strip()
    author = item.findtext("dc:creator", "", ns).strip()

    date = ""

    try:
        date = parsedate_to_datetime(pub).isoformat()
    except Exception:
        pass

    items.append({
        "title": title,
        "link": link,
        "date": date,
        "author": author
    })

read_links = set()
initialize_state = False

try:
    with open(state_file, "r", encoding="utf-8") as f:
        state = json.load(f)

    read_links = set(state.get("read_links", []))
except (FileNotFoundError, json.JSONDecodeError, OSError):
    # First run (or invalid state): use current feed as the baseline.
    # This prevents every existing article from appearing unread.
    read_links = {
        item["link"]
        for item in items
        if item["link"]
    }
    initialize_state = True

unread_count = 0

for item in items:
    item["unread"] = bool(
        item["link"]
        and item["link"] not in read_links
    )

    if item["unread"]:
        unread_count += 1

data = {
    "updated": datetime.datetime.now(
        datetime.timezone.utc
    ).isoformat(),
    "unread_count": unread_count,
    "items": items
}

with open(output_file, "w", encoding="utf-8") as f:
    json.dump(data, f, ensure_ascii=False, indent=2)
    f.write("\n")

if initialize_state:
    state_tmp = state_file + ".tmp"

    state = {
        "version": 1,
        "read_links": sorted(read_links)
    }

    with open(state_tmp, "w", encoding="utf-8") as f:
        json.dump(state, f, ensure_ascii=False, indent=2)
        f.write("\n")

    os.replace(state_tmp, state_file)
PYEOF

mv "$TMP_FILE" "$OUTPUT_FILE"

echo "wrote $OUTPUT_FILE"
