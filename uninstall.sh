#!/bin/bash
# Remove only the Herdr Drop files owned by this checkout.

set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
USER_HOME="${HERDR_DROP_HOME:-$HOME}"
BIN="${USER_HOME}/.local/bin"
CONFIG_ROOT="${XDG_CONFIG_HOME:-$HOME/.config}"
HYPR="$CONFIG_ROOT/hypr"
HYPRLAND="$HYPR/hyprland.lua"
DROP_CONFIG="$CONFIG_ROOT/herdr-drop/config"
STAMP="$(date +%s)"
PURGE=0
RELOAD=1

usage() {
  cat <<'USAGE'
Usage: ./uninstall.sh [--purge] [--no-reload]

  --purge       Also remove user-owned geometry and pane-title settings.
  --no-reload   Remove files without reloading Hyprland.
USAGE
}

while (( $# > 0 )); do
  case "$1" in
  --purge)
    PURGE=1
    shift
    ;;
  --no-reload)
    RELOAD=0
    shift
    ;;
  -h | --help)
    usage
    exit 0
    ;;
  *)
    echo "Unknown argument: $1" >&2
    usage >&2
    exit 2
    ;;
  esac
done

remove_owned_link() {
  local target="$1" expected="$2"
  [[ -L $target ]] || return 0
  if [[ $(readlink -f -- "$target") == $(readlink -f -- "$expected") ]]; then
    unlink -- "$target"
  else
    printf 'Preserved link not owned by this checkout: %s\n' "$target" >&2
  fi
}

remove_owned_link "$BIN/herdr-drop" "$SRC/bin/herdr-drop"
remove_owned_link "$HYPR/herdr-drop.lua" "$SRC/hypr/herdr-drop.lua"

if [[ -f $HYPRLAND ]]; then
  begin_count="$(grep -cFx -- '-- BEGIN herdr-drop' "$HYPRLAND" || true)"
  end_count="$(grep -cFx -- '-- END herdr-drop' "$HYPRLAND" || true)"
  if [[ $begin_count == 1 && $end_count == 1 ]]; then
    cp -a -- "$HYPRLAND" "$HYPRLAND.bak.$STAMP"
    temporary="$(mktemp "$(dirname "$HYPRLAND")/.herdr-drop-uninstall.XXXXXX")"
    awk '
      $0 == "-- BEGIN herdr-drop" { dropping = 1; next }
      $0 == "-- END herdr-drop" { dropping = 0; next }
      !dropping { print }
    ' "$HYPRLAND" >"$temporary"
    chmod --reference="$HYPRLAND" "$temporary"
    mv -- "$temporary" "$HYPRLAND"
  elif [[ $begin_count != 0 || $end_count != 0 ]]; then
    echo "Refusing to edit malformed herdr-drop marker block in $HYPRLAND" >&2
    exit 1
  fi
fi

if (( PURGE )); then
  [[ ! -f $HYPR/herdr-drop-settings.lua ]] \
    || mv -- "$HYPR/herdr-drop-settings.lua" "$HYPR/herdr-drop-settings.lua.bak.$STAMP"
  [[ ! -f $DROP_CONFIG ]] \
    || mv -- "$DROP_CONFIG" "$DROP_CONFIG.bak.$STAMP"
fi

if (( RELOAD )); then
  hyprctl reload >/dev/null
  errors="$(hyprctl configerrors)"
  if [[ -n $errors ]]; then
    printf 'Hyprland configuration errors:\n%s\n' "$errors" >&2
    exit 1
  fi
fi

echo "Herdr Drop uninstalled."
