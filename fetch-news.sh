#!/bin/bash
# fetch-news.sh — Arch Linux news fetcher for arch-widget
set -euo pipefail

DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/arch-widget"
HTML_FILE="$DATA_DIR/arch-widget.html"
FEED_URL="https://archlinux.org/feeds/news/"

mkdir -p "$DATA_DIR"

exec 9>"$DATA_DIR/.fetch-news.lock"
flock -w 10 9 || {
  echo "fetch-news: lock timeout" >&2
  exit 1
}

RSS_TMP=""
HTML_TMP=""

cleanup() {
    if [[ -n "$RSS_TMP" ]]; then
        rm -f -- "$RSS_TMP"
    fi

    if [[ -n "$HTML_TMP" ]]; then
        rm -f -- "$HTML_TMP"
    fi
}

trap cleanup EXIT

RSS_TMP=$(mktemp "$DATA_DIR/.rss.XXXXXXXX")
HTML_TMP=$(mktemp "$DATA_DIR/.html.XXXXXXXX")

if [[ -n "${TEST_RSS_FILE:-}" ]]; then
    cp -- "$TEST_RSS_FILE" "$RSS_TMP"
else
    curl --fail --silent --show-error \
         --location --max-time 10 \
         --output "$RSS_TMP" \
         "$FEED_URL"
fi

python3 - "$RSS_TMP" "$HTML_FILE" "$HTML_TMP" <<'PYCODE'
import datetime
import json
import re
import sys
import xml.etree.ElementTree as ET
from email.utils import parsedate_to_datetime
from pathlib import Path

rss_path, html_path, output_path = map(Path, sys.argv[1:4])

root = ET.parse(rss_path).getroot()
ns = {"dc": "http://purl.org/dc/elements/1.1/"}

items = []

for item in root.findall(".//item")[:12]:
    title = item.findtext("title", "").strip()
    link = item.findtext("link", "").strip()
    pub = item.findtext("pubDate", "").strip()
    author = item.findtext("dc:creator", "", ns).strip()

    date = ""
    try:
        date = parsedate_to_datetime(pub).strftime("%Y-%m-%d")
    except (ValueError, TypeError, IndexError):
        pass

    items.append({
        "title": title,
        "link": link,
        "date": date,
        "author": author
    })

data = {
    "updated": datetime.datetime.now().strftime("%H:%M"),
    "items": items
}

html = html_path.read_text(encoding="utf-8")

html = re.sub(
    r"// __ARCH_NEWS_START__.*?// __ARCH_NEWS_END__\n",
    "",
    html,
    flags=re.DOTALL
)

html = re.sub(
    r"// __INTERCEPT_START__.*?// __INTERCEPT_END__\n",
    "",
    html,
    flags=re.DOTALL
)

json_text = json.dumps(data, ensure_ascii=False)
json_text = (
    json_text.replace("&", "\\u0026")
             .replace("<", "\\u003c")
             .replace(">", "\\u003e")
)

injection = (
    "// __ARCH_NEWS_START__\n"
    "const ARCH_NEWS_DATA = " + json_text + ";\n"
    "// __ARCH_NEWS_END__\n"
)



if html.count("<script>\n") != 1 or "</script>" not in html:
    raise ValueError("invalid HTML injection structure")


html = html.replace("<script>\n", "<script>\n" + injection, 1)

output_path.write_text(html, encoding="utf-8")

print(f"injected {len(items)} items into {html_path!s}")
PYCODE

chmod --reference="$HTML_FILE" "$HTML_TMP"
mv -f -- "$HTML_TMP" "$HTML_FILE"
