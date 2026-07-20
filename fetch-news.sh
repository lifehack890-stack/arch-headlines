#!/bin/bash
# fetch-news.sh — Arch Linux news fetcher for arch-widget
set -euo pipefail

DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/arch-widget"
HTML_FILE="$DATA_DIR/arch-widget.html"
FEED_URL="https://archlinux.org/feeds/news/"

mkdir -p "$DATA_DIR"

XML=$(curl -s --max-time 10 "$FEED_URL") || {
  echo "fetch failed" >&2
  exit 1
}

JSON=$(python3 - << PYEOF
import xml.etree.ElementTree as ET, json, re
from email.utils import parsedate_to_datetime

xml = r"""$XML"""
root = ET.fromstring(xml)
ns = {'dc': 'http://purl.org/dc/elements/1.1/'}

items = []
for item in root.findall('.//item')[:12]:
    title  = item.findtext('title', '').strip()
    link   = item.findtext('link', '').strip()
    pub    = item.findtext('pubDate', '').strip()
    author = item.findtext('dc:creator', '', ns).strip()
    date   = ''
    try:
        date = parsedate_to_datetime(pub).strftime('%Y-%m-%d')
    except:
        pass
    items.append({'title': title, 'link': link, 'date': date, 'author': author})

import datetime
out = {'updated': datetime.datetime.now().strftime('%H:%M'), 'items': items}
print(json.dumps(out, ensure_ascii=False))
PYEOF
)

# Inject JSON into HTML as a JS variable
# Remove old injection if exists, then prepend new one after <script>
python3 - << PYEOF2
import json, re

html = open('$HTML_FILE').read()
data = json.loads(r"""$JSON""")

# Remove previous injection block
html = re.sub(r'// __ARCH_NEWS_START__.*?// __ARCH_NEWS_END__\n', '', html, flags=re.DOTALL)

injection = "// __ARCH_NEWS_START__\nconst ARCH_NEWS_DATA = " + json.dumps(data, ensure_ascii=False) + ";\n// __ARCH_NEWS_END__\n"

interceptor = '''
// __INTERCEPT_START__
document.addEventListener('click', function(e) {
  const a = e.target.closest('a');
  if (a && a.href && a.href.startsWith('http')) {
    e.preventDefault();
    document.title = 'open:' + a.href;
    setTimeout(() => { document.title = 'expanded'; }, 500);
  }
}, true);
// __INTERCEPT_END__
'''
html = re.sub(r'// __INTERCEPT_START__.*?// __INTERCEPT_END__\n', '', html, flags=re.DOTALL)
html = html.replace('</script>', interceptor + '</script>', 1)
html = html.replace('<script>\n', '<script>\n' + injection, 1)
open('$HTML_FILE', 'w').write(html)
print(f"injected {len(data['items'])} items into {repr('$HTML_FILE')}")
PYEOF2
