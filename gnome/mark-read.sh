#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 1 ]; then
    echo "usage: $0 <article-url>" >&2
    exit 1
fi

ARTICLE_URL="$1"

DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/arch-headlines-gnome"
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

python3 - "$ARTICLE_URL" "$STATE_FILE" "$STATE_TMP" <<'PY'
import json
import sys

article_url, state_file, state_tmp = sys.argv[1:4]

try:
    with open(state_file, "r", encoding="utf-8") as f:
        state = json.load(f)
except FileNotFoundError:
    state = {"read_links": []}

read_links = set(state.get("read_links", []))
read_links.add(article_url)

state["read_links"] = list(read_links)

with open(state_tmp, "w", encoding="utf-8") as f:
    json.dump(state, f, ensure_ascii=False, indent=2)
    f.write("\n")
PY

mv "$STATE_TMP" "$STATE_FILE"
trap - EXIT

cat "$STATE_FILE"
