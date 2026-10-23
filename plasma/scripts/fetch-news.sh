#!/bin/bash
set -euo pipefail

DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/arch-headlines-plasma"
FEED_URL="https://archlinux.org/feeds/news/"
OUTPUT_FILE="$DATA_DIR/news.json"
STATE_FILE="$DATA_DIR/state.json"
LOCK_FILE="$DATA_DIR/state.lock"

mkdir -p "$DATA_DIR"

FEED_TMP=$(mktemp "$DATA_DIR/feed.xml.tmp.XXXXXX")
NEWS_TMP=""
STATE_TMP=""

cleanup() {
    for file in "$FEED_TMP" "$NEWS_TMP" "$STATE_TMP"; do
        if [[ -n "$file" ]]; then
            rm -f -- "$file"
        fi
    done
}
trap cleanup EXIT

# Network access stays outside the lock.
# Reject excessive feed bodies before they reach the XML parser.
MAX_FEED_BYTES=1048576
curl -fsS --max-time 10 --max-filesize "$MAX_FEED_BYTES" -o "$FEED_TMP" "$FEED_URL"
if (( $(stat -c %s -- "$FEED_TMP") > MAX_FEED_BYTES )); then
    echo "arch-headlines: feed error: RSS exceeds size limit" >&2
    exit 1
fi

exec 9>"$LOCK_FILE"
flock -w 10 9 || { echo "arch-headlines: lock acquisition failed or timed out (10s)" >&2; exit 1; }

NEWS_TMP=$(mktemp "$DATA_DIR/news.json.tmp.XXXXXX")
STATE_TMP=$(mktemp "$DATA_DIR/state.json.tmp.XXXXXX")

python3 - "$FEED_TMP" "$NEWS_TMP" "$STATE_FILE" "$STATE_TMP" <<'PYEOF'
import sys
import json
import datetime
import hashlib
import re
import xml.etree.ElementTree as ET
from email.utils import parsedate_to_datetime

feed_file, output_file, state_file, state_tmp = sys.argv[1:5]

root = ET.parse(feed_file).getroot()
channel = root.find("channel") if root.tag == "rss" else None
if channel is None:
    print("arch-headlines: feed error: expected RSS channel", file=sys.stderr)
    sys.exit(1)

feed_items = channel.findall("item")
if not feed_items:
    print("arch-headlines: feed error: no RSS items", file=sys.stderr)
    sys.exit(1)

ns = {
    "dc": "http://purl.org/dc/elements/1.1/"
}

items = []

for item in feed_items[:12]:
    title = item.findtext("title", "").strip()
    link = item.findtext("link", "").strip()
    pub = item.findtext("pubDate", "").strip()
    author = item.findtext("dc:creator", "", ns).strip()

    # A broken item must not silently replace the last known-good feed.
    if not title or not re.fullmatch(
        r"https://archlinux\.org/news/[a-z0-9-]+/", link
    ):
        print("arch-headlines: feed error: invalid RSS item", file=sys.stderr)
        sys.exit(1)

    date = ""

    try:
        date = parsedate_to_datetime(pub).isoformat()
    except Exception:
        pass

    items.append({
        "title": title,
        "link": link,
        "id": hashlib.sha256(link.encode("utf-8")).hexdigest() if link else "",
        "date": date,
        "author": author
    })

read_links = set()
initialize_state = False

try:
    with open(state_file, "r", encoding="utf-8") as f:
        state = json.load(f)
except FileNotFoundError:
    # Only a missing state file is treated as a first run.
    read_links = {
        item["link"]
        for item in items
        if item["link"]
    }
    initialize_state = True
except (json.JSONDecodeError, OSError) as exc:
    print(f"arch-headlines: state error: {exc}", file=sys.stderr)
    sys.exit(1)
else:
    if (
        not isinstance(state, dict)
        or type(state.get("version")) is not int
        or state["version"] != 1
        or not isinstance(state.get("read_links"), list)
        or not all(
            isinstance(link, str) and bool(link)
            for link in state["read_links"]
        )
    ):
        print(
            "arch-headlines: state error: invalid schema",
            file=sys.stderr
        )
        sys.exit(1)

    read_links = set(state["read_links"])

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
    state = {
        "version": 1,
        "read_links": sorted(read_links)
    }

    with open(state_tmp, "w", encoding="utf-8") as f:
        json.dump(state, f, ensure_ascii=False, indent=2)
        f.write("\n")
PYEOF

# Publish the authoritative read state first on initial startup.
# If the following news.json rename fails, the next fetch can rebuild
# news.json from state.json without losing the first-run read snapshot.
if [ -s "$STATE_TMP" ]; then
    mv "$STATE_TMP" "$STATE_FILE"
fi

mv "$NEWS_TMP" "$OUTPUT_FILE"


echo "wrote $OUTPUT_FILE"
