#!/bin/bash
set -euo pipefail

DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/arch-headlines-plasma"
NEWS_FILE="$DATA_DIR/news.json"
STATE_FILE="$DATA_DIR/state.json"
LOCK_FILE="$DATA_DIR/state.lock"

mkdir -p "$DATA_DIR"

exec 9>"$LOCK_FILE"
flock -w 10 9 || { echo "arch-headlines: lock acquisition failed or timed out (10s)" >&2; exit 1; }

STATE_TMP=$(mktemp "$DATA_DIR/state.json.tmp.XXXXXX")
NEWS_TMP=$(mktemp "$DATA_DIR/news.json.tmp.XXXXXX")

cleanup() {
    rm -f "$STATE_TMP" "$NEWS_TMP"
}
trap cleanup EXIT

python3 - "$NEWS_FILE" "$STATE_FILE" "$STATE_TMP" "$NEWS_TMP" <<'PYEOF'
import sys
import json

news_file, state_file, state_tmp, news_tmp = sys.argv[1:5]

with open(news_file, "r", encoding="utf-8") as f:
    news = json.load(f)

try:
    with open(state_file, "r", encoding="utf-8") as f:
        state = json.load(f)
except (FileNotFoundError, json.JSONDecodeError, OSError):
    state = {
        "version": 1,
        "read_links": []
    }

read_links = set(state.get("read_links", []))

for item in news.get("items", []):
    link = item.get("link", "")

    if link:
        read_links.add(link)

    item["unread"] = False

news["unread_count"] = 0

state = {
    "version": 1,
    "read_links": sorted(read_links)
}

with open(state_tmp, "w", encoding="utf-8") as f:
    json.dump(state, f, ensure_ascii=False, indent=2)
    f.write("\n")

with open(news_tmp, "w", encoding="utf-8") as f:
    json.dump(news, f, ensure_ascii=False, indent=2)
    f.write("\n")
PYEOF

mv "$STATE_TMP" "$STATE_FILE"
mv "$NEWS_TMP" "$NEWS_FILE"


cat "$NEWS_FILE"
