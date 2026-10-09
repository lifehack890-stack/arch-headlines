#!/bin/bash
set -euo pipefail

if [ "$#" -ne 1 ]; then
    echo "usage: $0 <article-url>" >&2
    exit 1
fi

ARTICLE_URL="$1"

DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/arch-headlines-plasma"
NEWS_FILE="$DATA_DIR/news.json"
STATE_FILE="$DATA_DIR/state.json"
LOCK_FILE="$DATA_DIR/state.lock"

mkdir -p "$DATA_DIR"

exec 9>"$LOCK_FILE"
flock 9

STATE_TMP=$(mktemp "$DATA_DIR/state.json.tmp.XXXXXX")
NEWS_TMP=$(mktemp "$DATA_DIR/news.json.tmp.XXXXXX")

cleanup() {
    rm -f "$STATE_TMP" "$NEWS_TMP"
}
trap cleanup EXIT

python3 - "$ARTICLE_URL" "$NEWS_FILE" "$STATE_FILE" "$STATE_TMP" "$NEWS_TMP" <<'PY'
import json
import sys

article_url, news_file, state_file, state_tmp, news_tmp = sys.argv[1:6]

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
read_links.add(article_url)

for item in news.get("items", []):
    if item.get("link") == article_url:
        item["unread"] = False

news["unread_count"] = sum(
    1 for item in news.get("items", [])
    if item.get("unread")
)

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
PY

mv "$STATE_TMP" "$STATE_FILE"
mv "$NEWS_TMP" "$NEWS_FILE"


cat "$NEWS_FILE"
