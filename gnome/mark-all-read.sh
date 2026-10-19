#!/usr/bin/env bash
set -euo pipefail

DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/arch-headlines-gnome"
NEWS_FILE="$DATA_DIR/news.json"
STATE_FILE="$DATA_DIR/state.json"
LOCK_FILE="$DATA_DIR/state.lock"

mkdir -p "$DATA_DIR"

exec 9>"$LOCK_FILE"
flock 9

STATE_TMP=$(mktemp "$DATA_DIR/state.json.tmp.XXXXXX")

cleanup() {
    rm -f "$STATE_TMP"
}
trap cleanup EXIT

python3 - "$NEWS_FILE" "$STATE_FILE" "$STATE_TMP" <<'PY'
import json
import sys

news_file, state_file, state_tmp = sys.argv[1:4]

with open(news_file, "r", encoding="utf-8") as f:
    news = json.load(f)

try:
    with open(state_file, "r", encoding="utf-8") as f:
        state = json.load(f)
except FileNotFoundError:
    state = {"read_links": []}

read_links = set(state.get("read_links", []))

for item in news.get("items", []):
    link = item.get("link", "")
    if link:
        read_links.add(link)

state["read_links"] = list(read_links)

with open(state_tmp, "w", encoding="utf-8") as f:
    json.dump(state, f, ensure_ascii=False, indent=2)
    f.write("\n")
PY

mv "$STATE_TMP" "$STATE_FILE"
trap - EXIT

cat "$STATE_FILE"
