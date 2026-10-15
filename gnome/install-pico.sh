#!/usr/bin/env bash
set -euo pipefail

if [[ "$#" -ne 2 || "$1" != "--stage" ]]; then
    echo "Usage: $0 --stage /tmp/pico-stage.XXXXXX" >&2
    exit 2
fi

STAGE="$(realpath -- "$2")"
if [[ "$STAGE" != /tmp/pico-stage.* || ! -d "$STAGE" ]]; then
    echo "Invalid staging directory" >&2
    exit 2
fi

if [[ -n "$(find "$STAGE" -type l -print -quit)" ]]; then
    echo "Refusing staging directory containing symlinks" >&2
    exit 2
fi

if [[ -n "$(find "$STAGE" -mindepth 1 -print -quit)" ]]; then
    echo "Refusing non-empty staging directory" >&2
    exit 2
fi

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD="$(mktemp -d /tmp/pico-build.XXXXXX)"
trap 'rm -rf -- "$BUILD"' EXIT
EXT="$BUILD/gnome-shell/extensions/arch-headlines@lifehack890-stack"
UNITS="$BUILD/systemd/user"

install -d "$EXT" "$UNITS"
install -m 644 "$SRC"/{extension.js,metadata.json,arch-headlines.svg} "$EXT/"
install -m 755 "$SRC"/{fetch-news.sh,mark-read.sh,mark-all-read.sh} "$EXT/"
install -m 644 "$SRC"/arch-headlines-pico-news.{service,timer} "$UNITS/"

mv -T -- "$BUILD" "$STAGE"
trap - EXIT

echo "Pico staging: PASS"
