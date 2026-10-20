#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 || ( "$1" != '--dry-run' && "$1" != '--install' ) ]]; then
    echo "Usage: $0 --dry-run|--install" >&2
    exit 2
fi
mode=$1
src=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
root="$HOME/.local/share/gnome-shell/extensions"
ext="$root/arch-headlines@lifehack890-stack"
units="$HOME/.config/systemd/user"
data="${XDG_DATA_HOME:-$HOME/.local/share}/arch-headlines-gnome"
files=(extension.js metadata.json arch-headlines.svg fetch-news.sh mark-read.sh mark-all-read.sh)
unit_files=(arch-headlines-pico-news.service arch-headlines-pico-news.timer)

for f in "${files[@]}" "${unit_files[@]}"; do
    if [[ ! -f "$src/$f" || -L "$src/$f" || ! -r "$src/$f" ]]; then
        echo "PREFLIGHT FAIL: $f" >&2; exit 2
    fi
done
for f in fetch-news.sh mark-read.sh mark-all-read.sh; do
    bash -n "$src/$f" || exit 2
done
for p in "$root" "$ext" "$units" "$data"; do
    if [[ -L "$p" ]]; then
        echo "PREFLIGHT FAIL: symlink target $p" >&2; exit 2
    fi
done
for f in "${unit_files[@]}"; do
    if [[ -L "$units/$f" ||
          ( -e "$units/$f" && ! -f "$units/$f" ) ]]; then
        echo "PREFLIGHT FAIL: unsafe existing unit $f" >&2
        exit 2
    fi
done
printf 'PREFLIGHT: PASS (8 source files)\n'
printf 'Extension: %s\nUnits: %s\nProtected data: %s\n' "$ext" "$units" "$data"
if [[ "$mode" == --dry-run ]]; then
    echo 'DRY RUN: no changes performed'
    echo 'PLAN: stage, back up extension and units, switch, verify, retain backup'
    echo 'Systemd activation: NOT PERFORMED'
    exit 0
fi

if [[ "${PICO_ALLOW_LIVE_INSTALL:-}" != "YES" ]]; then
    echo 'LIVE INSTALL BLOCKED: set PICO_ALLOW_LIVE_INSTALL=YES after review' >&2
    exit 2
fi
command -v systemd-analyze >/dev/null || { echo 'Missing systemd-analyze' >&2; exit 2; }
command -v flock >/dev/null || { echo 'Missing flock' >&2; exit 2; }

mkdir -p -- "$root"

lock_file="$root/.pico-install.lock"
if [[ -L "$lock_file" ||
      ( -e "$lock_file" && ! -f "$lock_file" ) ]]; then
    echo "INSTALL BLOCKED: unsafe lock file $lock_file" >&2
    exit 2
fi

exec {lock_fd}>>"$lock_file"
if ! flock -n "$lock_fd"; then
    echo 'INSTALL BLOCKED: another Pico installation is running' >&2
    exit 3
fi

mkdir -p -- "$units"

stage=$(mktemp -d "$root/.pico-stage.XXXXXXXX")
backup=$(mktemp -d "$root/.pico-backup.XXXXXXXX")
mkdir -p -- "$stage/extension" "$stage/units" "$backup/units"
units_touched=0
committed=0
tmp_unit=""
on_exit() {
    local rc=$?
    trap - EXIT
    if [[ -n "$tmp_unit" && -e "$tmp_unit" ]]; then
        rm -f -- "$tmp_unit" || {
            echo "WARNING: temporary unit cleanup failed: $tmp_unit" >&2
        }
    fi
    if (( rc != 0 && committed == 0 )); then
        echo 'INSTALL FAILED: attempting rollback' >&2
        local restore_ok=1
        if [[ ! -d "$stage/extension" && -d "$ext" ]]; then
            mv -T -- "$ext" "$stage/failed-extension" || restore_ok=0
        fi
        if [[ -d "$backup/extension" ]]; then
            mv -T -- "$backup/extension" "$ext" || restore_ok=0
        fi
        if (( units_touched )); then
            for f in "${unit_files[@]}"; do
                if [[ -f "$backup/units/$f" ]]; then
                    local restore_tmp=""
                    restore_tmp=$(mktemp -- "$units/.pico-restore.XXXXXXXX") || {
                        restore_ok=0
                        continue
                    }
                    if ! cp -p -- "$backup/units/$f" "$restore_tmp" ||
                       ! cmp -s -- "$backup/units/$f" "$restore_tmp" ||
                       ! mv -T -- "$restore_tmp" "$units/$f"; then
                        restore_ok=0
                        rm -f -- "$restore_tmp" || true
                    fi
                else
                    rm -f -- "$units/$f" || restore_ok=0
                fi
            done
        fi
        if (( restore_ok )); then echo 'ROLLBACK: PASS' >&2; else echo 'ROLLBACK: INCOMPLETE (inspect backup)' >&2; fi
        echo "Preserved recovery directory: $backup" >&2
        echo "Preserved staging directory: $stage" >&2
    fi
    exit "$rc"
}
trap on_exit EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

for f in "${files[@]}"; do
    case "$f" in *.sh) m=755;; *) m=644;; esac
    install -m "$m" -- "$src/$f" "$stage/extension/$f"
    cmp -s -- "$src/$f" "$stage/extension/$f" || { echo "STAGE FAIL: $f" >&2; exit 1; }
done
for f in "${unit_files[@]}"; do
    install -m 644 -- "$src/$f" "$stage/units/$f"
    if [[ -e "$units/$f" ]]; then
        cp -a -- "$units/$f" "$backup/units/$f"
        cmp -s -- "$units/$f" "$backup/units/$f" || {
            echo "BACKUP FAIL: unit mismatch $f" >&2
            exit 1
        }
    fi
done
systemd-analyze --user verify "$stage/units/${unit_files[0]}" "$stage/units/${unit_files[1]}"
if [[ -e "$ext" ]]; then
    [[ -d "$ext" ]] || { echo 'INSTALL FAIL: extension target is not a directory' >&2; exit 1; }
    mv -T -- "$ext" "$backup/extension"
fi
mv -T -- "$stage/extension" "$ext"
units_touched=1
for f in "${unit_files[@]}"; do
    tmp_unit=$(mktemp -- "$units/.pico-unit.XXXXXXXX")
    install -m 644 -- "$stage/units/$f" "$tmp_unit"
    cmp -s -- "$src/$f" "$tmp_unit" || {
        echo "INSTALL FAIL: staged unit mismatch $f" >&2
        exit 1
    }
    mv -T -- "$tmp_unit" "$units/$f"
    tmp_unit=""
    cmp -s -- "$src/$f" "$units/$f" || {
        echo "INSTALL FAIL: unit mismatch $f" >&2
        exit 1
    }
done
for f in "${files[@]}"; do
    cmp -s -- "$src/$f" "$ext/$f" || { echo "INSTALL FAIL: extension mismatch $f" >&2; exit 1; }
done
committed=1
if ! rm -rf -- "$stage"; then
    echo "WARNING: staging cleanup failed: $stage" >&2
fi
echo 'INSTALL: PASS (extension and units installed)'
echo "Backup retained: $backup"
echo 'Timer NOT enabled or started; user daemon NOT reloaded'
echo 'News and read-state JSON: NOT TOUCHED'
