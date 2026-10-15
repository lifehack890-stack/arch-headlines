#!/usr/bin/env bash
set -euo pipefail

if [[ "$#" -ne 2 || "$1" != "--simulate" ]]; then
    echo "Usage: $0 --simulate /tmp/pico-upgrade-auto.XXXXXX" >&2
    exit 2
fi

SIM="$(realpath -e -- "$2")"

if [[ "$SIM" != /tmp/pico-upgrade-auto.* ||
      ! -d "$SIM/current" ||
      -L "$SIM/current" ||
      -e "$SIM/candidate" || -L "$SIM/candidate" ||
      -e "$SIM/previous" || -L "$SIM/previous" ||
      "$(stat -c %u "$SIM")" != "$EUID" ||
      "$(stat -c %a "$SIM")" != 700 ]]; then
    echo "SIM PREFLIGHT: FAIL" >&2
    exit 2
fi

if [[ -n "$(find "$SIM" -type l -print -quit)" ]]; then
    echo "SIM PREFLIGHT: symlink detected" >&2
    exit 2
fi

echo "SIM PREFLIGHT: PASS"

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

for f in extension.js metadata.json arch-headlines.svg \
         fetch-news.sh mark-read.sh mark-all-read.sh; do
    if [[ ! -f "$SRC/$f" || -L "$SRC/$f" || ! -r "$SRC/$f" ]]; then
        echo "SIM SOURCE FAIL: $f" >&2
        exit 2
    fi
done

BUILD="$(mktemp -d "$SIM/.candidate.XXXXXXXX")"
trap 'rm -rf -- "$BUILD"' EXIT

install -m 644 "$SRC"/{extension.js,metadata.json,arch-headlines.svg} "$BUILD/"
install -m 755 "$SRC"/{fetch-news.sh,mark-read.sh,mark-all-read.sh} "$BUILD/"

mv -T -- "$BUILD" "$SIM/candidate"
trap - EXIT

echo "SIM CANDIDATE: PASS"
