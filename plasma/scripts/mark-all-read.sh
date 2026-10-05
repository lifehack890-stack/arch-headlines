#!/bin/bash
set -euo pipefail

DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/arch-headlines-plasma"
NEWS_FILE="$DATA_DIR/news.json"
STATE_FILE="$DATA_DIR/state.json"

python3 - "$NEWS_FILE" "$STATE_FILE" <<'PYEOF'
import sys
import os
import json

news_file = sys.argv[1]
state_file = sys.argv[2]

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

state_tmp = state_file + ".tmp"
news_tmp = news_file + ".tmp"

with open(state_tmp, "w", encoding="utf-8") as f:
    json.dump(state, f, ensure_ascii=False, indent=2)
    f.write("\n")

with open(news_tmp, "w", encoding="utf-8") as f:
    json.dump(news, f, ensure_ascii=False, indent=2)
    f.write("\n")

os.replace(state_tmp, state_file)
os.replace(news_tmp, news_file)

print(json.dumps(news, ensure_ascii=False))
PYEOF
