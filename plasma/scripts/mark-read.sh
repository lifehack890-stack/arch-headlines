#!/bin/bash
set -euo pipefail

if [ "$#" -ne 1 ]; then
    echo "usage: $0 <article-id>" >&2
    exit 1
fi

ARTICLE_ID="$1"
if [[ ! "$ARTICLE_ID" =~ ^[0-9a-f]{64}$ ]]; then
    echo "arch-headlines: invalid article ID" >&2
    exit 1
fi

DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/arch-headlines-plasma"
NEWS_FILE="$DATA_DIR/news.json"
STATE_FILE="$DATA_DIR/state.json"
LOCK_FILE="$DATA_DIR/state.lock"

mkdir -p "$DATA_DIR"

exec 9>"$LOCK_FILE"
flock -w 10 9 || { echo "arch-headlines: lock acquisition failed or timed out (10s)" >&2; exit 1; }

STATE_TMP=""
NEWS_TMP=""

cleanup() {
    for file in "$STATE_TMP" "$NEWS_TMP"; do
        if [[ -n "$file" ]]; then
            rm -f -- "$file"
        fi
    done
}
trap cleanup EXIT

STATE_TMP=$(mktemp "$DATA_DIR/state.json.tmp.XXXXXX")
NEWS_TMP=$(mktemp "$DATA_DIR/news.json.tmp.XXXXXX")

python3 - "$ARTICLE_ID" "$NEWS_FILE" "$STATE_FILE" "$STATE_TMP" "$NEWS_TMP" <<'PY'
import json
import hashlib
import sys

article_id, news_file, state_file, state_tmp, news_tmp = sys.argv[1:6]

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

matching_items = [
    item for item in news["items"]
    if item.get("id") == article_id
    and hashlib.sha256(
        item["link"].encode("utf-8")
    ).hexdigest() == article_id
]

if not matching_items:
    print(
        "arch-headlines: article error: ID not found or inconsistent",
        file=sys.stderr
    )
    sys.exit(1)

read_links = set(state["read_links"])
read_links.add(matching_items[0]["link"])

for item in matching_items:
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
