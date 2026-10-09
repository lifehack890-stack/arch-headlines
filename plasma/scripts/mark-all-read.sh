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

try:
    with open(news_file, "r", encoding="utf-8") as f:
        news = json.load(f)
except (json.JSONDecodeError, OSError) as exc:
    print(f"arch-headlines: news error: {exc}", file=sys.stderr)
    sys.exit(1)

if (
    not isinstance(news, dict)
    or not isinstance(news.get("items"), list)
    or type(news.get("unread_count")) is not int
    or news["unread_count"] < 0
    or not all(
        isinstance(item, dict)
        and isinstance(item.get("link"), str)
        and bool(item["link"])
        and type(item.get("unread")) is bool
        for item in news["items"]
    )
):
    print(
        "arch-headlines: news error: invalid schema",
        file=sys.stderr
    )
    sys.exit(1)

try:
    with open(state_file, "r", encoding="utf-8") as f:
        state = json.load(f)
except FileNotFoundError:
    # Missing state is treated as an initial state.
    state = {
        "version": 1,
        "read_links": []
    }
except (json.JSONDecodeError, OSError) as exc:
    print(f"arch-headlines: state error: {exc}", file=sys.stderr)
    sys.exit(1)

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
