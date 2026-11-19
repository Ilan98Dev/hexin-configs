#!/usr/bin/env bash
# Run install.sh against a throwaway HOME with every system command stubbed.
# Usage: tests/install-smoke.sh
set -uo pipefail

REPO="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$(mktemp -d /tmp/opencode/hyprunity-smoke.XXXXXX)"
STUB="$WORK/bin"
FAKE="$WORK/home"
LOG="$WORK/commands.log"
PASS=0
FAIL=0

ok()   { PASS=$((PASS + 1)); printf '  ok   %s\n' "$*"; }
bad()  { FAIL=$((FAIL + 1)); printf '  FAIL %s\n' "$*"; }
check(){ if eval "$2"; then ok "$1"; else bad "$1"; fi; }

mkdir -p "$STUB" "$FAKE"

for name in sudo pacman systemctl hyprctl qs; do
  case "$name" in
    sudo) body='#!/bin/sh\nexec "$@"' ;;
    *)    body='#!/bin/sh\necho "'"$name"' $*" >> "$SMOKE_LOG"\nexit 0' ;;
  esac
  printf '%b\n' "$body" >"$STUB/$name"
  chmod +x "$STUB/$name"
done

run_install() {
  env -i HOME="$FAKE" PATH="$STUB:/usr/bin:/bin" SMOKE_LOG="$LOG" TERM=dumb \
    ${1:+HYPRLAND_INSTANCE_SIGNATURE=fake} bash "$REPO/install.sh" >"$WORK/out.log" 2>&1
  echo $? >"$WORK/rc"
}

echo "== fresh install"
run_install
check "installer exits 0" '[ "$(cat "$WORK/rc")" = 0 ]'
check "quickshell tree copied" '[ -f "$FAKE/.config/quickshell/hyprunity/shell.qml" ]'
check "quickshell tree matches repo" 'diff -r "$REPO/dotfiles/config/quickshell/hyprunity" "$FAKE/.config/quickshell/hyprunity" >/dev/null'
check "hyprland.lua installed" '[ -f "$FAKE/.config/hypr/hyprland.lua" ]'
check "hypr lua tree matches repo" 'diff -r "$REPO/dotfiles/config/hypr/hyprunity" "$FAKE/.config/hypr/hyprunity" >/dev/null'
check "settings.json installed" '[ -f "$FAKE/.config/hyprunity/settings.json" ]'
check "shipped preset is UnityOS" 'grep -q "\"preset\": \"UnityOS\"" "$FAKE/.config/hyprunity/settings.json"'
check "shipped welcomeSeen is false" 'grep -q "\"welcomeSeen\": false" "$FAKE/.config/hyprunity/settings.json"'
check "matugen templates installed" '[ -d "$FAKE/.config/matugen" ]'
check "helper scripts executable" '[ -x "$FAKE/.local/bin/hyprunity-theme-sync" ] && [ -x "$FAKE/.local/bin/hyprunity-matugen-apply" ]'
check "kitty include written" 'grep -q "include hyprunity-theme.conf" "$FAKE/.config/kitty/kitty.conf"'
check "xdg-utils requested" 'grep -q "xdg-utils" "$LOG"'
check "zen-browser-bin requested" 'grep -q "zen-browser-bin" "$LOG"'
check "spotlight shipped" '[ -f "$FAKE/.config/quickshell/hyprunity/modules/panels/Spotlight.qml" ]'

echo "== reinstall over user files"
mkdir -p "$FAKE/.config/quickshell/hyprunity/modules/panels"
echo "// user edit" >"$FAKE/.config/quickshell/hyprunity/modules/panels/Spotlight.qml"
echo "old conf" >"$FAKE/.config/hypr/hyprland.conf"
BEFORE=$(ls -d "$FAKE"/.local/state/hyprunity/install-backup-* 2>/dev/null | wc -l)
run_install
check "reinstall exits 0" '[ "$(cat "$WORK/rc")" = 0 ]'
check "a new backup folder appeared" '[ "$(ls -d "$FAKE"/.local/state/hyprunity/install-backup-* 2>/dev/null | wc -l)" -gt "$BEFORE" ]'
check "edited Spotlight was backed up" 'grep -rq "// user edit" "$FAKE"/.local/state/hyprunity/install-backup-*/'
check "hyprland.conf moved aside" '[ ! -f "$FAKE/.config/hypr/hyprland.conf" ]'
check "hyprland.conf is in the backup" 'grep -rq "old conf" "$FAKE"/.local/state/hyprunity/install-backup-*/'
check "Spotlight restored from repo" 'diff -q "$REPO/dotfiles/config/quickshell/hyprunity/modules/panels/Spotlight.qml" "$FAKE/.config/quickshell/hyprunity/modules/panels/Spotlight.qml" >/dev/null'

echo "== inside a Hyprland session"
: >"$LOG"
run_install inside
check "session install exits 0" '[ "$(cat "$WORK/rc")" = 0 ]'
check "hyprctl reload called" 'grep -q "hyprctl reload" "$LOG"'
check "shell reload requested" 'grep -q "qs ipc -c hyprunity call shell reload" "$LOG"'

echo
echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ] || { echo "log: $WORK"; exit 1; }
rm -rf "$WORK"
