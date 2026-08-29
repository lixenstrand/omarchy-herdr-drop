#!/bin/bash
# Install the versioned Herdr Drop integration into user-owned Omarchy config.

set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
USER_HOME="${HERDR_DROP_HOME:-$HOME}"
BIN="${USER_HOME}/.local/bin"
CONFIG_ROOT="${XDG_CONFIG_HOME:-$HOME/.config}"
HYPR="$CONFIG_ROOT/hypr"
HYPRLAND="$HYPR/hyprland.lua"
DROP_CONFIG="$CONFIG_ROOT/herdr-drop/config"
STAMP="$(date +%s)"
FOCUS_TITLE=""
FOCUS_TITLE_SET=0
RELOAD=1

usage() {
  cat <<'USAGE'
Usage: ./install.sh [--focus-title TEXT] [--no-reload]

  --focus-title TEXT  Focus the first Herdr pane whose title contains TEXT
                      when the drop-down client is first created.
  --no-reload         Install files without reloading Hyprland.
USAGE
}

while (( $# > 0 )); do
  case "$1" in
  --focus-title)
    (( $# >= 2 )) || { echo "--focus-title requires a value" >&2; exit 2; }
    FOCUS_TITLE="$2"
    [[ $FOCUS_TITLE != *$'\n'* ]] || {
      echo "--focus-title must be one line" >&2
      exit 2
    }
    FOCUS_TITLE_SET=1
    shift 2
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

for command_name in herdr jq hyprctl omarchy omarchy-launch-tui; do
  command -v "$command_name" >/dev/null 2>&1 || {
    echo "Missing required command: $command_name" >&2
    exit 1
  }
done

[[ -f $HYPRLAND ]] || {
  echo "Omarchy Hyprland configuration not found: $HYPRLAND" >&2
  exit 1
}

previous_binding="$(omarchy menu keybindings --print 2>/dev/null \
  | awk '$1 == "SUPER" && $2 == "+" && $3 == "A" && !found { print; found = 1 }')"
if [[ -n $previous_binding ]]; then
  printf 'SUPER+A was previously bound: %s\n' "$previous_binding"
else
  echo "SUPER+A had no previous binding."
fi

mkdir -p "$BIN" "$HYPR" "$(dirname "$DROP_CONFIG")"

backup() {
  local target="$1"
  [[ -e $target || -L $target ]] || return 0
  cp -a -- "$target" "$target.bak.$STAMP"
}

link_file() {
  local source="$1" target="$2"
  if [[ -L $target && $(readlink -f -- "$target") == $(readlink -f -- "$source") ]]; then
    return 0
  fi
  backup "$target"
  ln -sfn -- "$source" "$target"
}

link_file "$SRC/bin/herdr-drop" "$BIN/herdr-drop"
link_file "$SRC/hypr/herdr-drop.lua" "$HYPR/herdr-drop.lua"

if [[ ! -f $HYPR/herdr-drop-settings.lua ]]; then
  install -m 600 "$SRC/hypr/herdr-drop-settings.lua" \
    "$HYPR/herdr-drop-settings.lua"
fi

write_focus_config=0
if [[ ! -f $DROP_CONFIG ]]; then
  write_focus_config=1
elif (( FOCUS_TITLE_SET )) && ! grep -qFx -- "$FOCUS_TITLE" "$DROP_CONFIG"; then
  write_focus_config=1
fi

if (( write_focus_config )); then
  [[ ! -f $DROP_CONFIG ]] || backup "$DROP_CONFIG"
  printf '%s\n' "$FOCUS_TITLE" >"$DROP_CONFIG"
  chmod 600 "$DROP_CONFIG"
fi

require_line='require("hypr.herdr-drop")'
if ! grep -qF -- "$require_line" "$HYPRLAND"; then
  backup "$HYPRLAND"
  {
    printf '\n-- BEGIN herdr-drop\n'
    printf '%s\n' "$require_line"
    printf '%s\n' '-- END herdr-drop'
  } >>"$HYPRLAND"
fi

if (( RELOAD )); then
  hyprctl reload >/dev/null
  errors="$(hyprctl configerrors)"
  if [[ -n $errors ]]; then
    printf 'Hyprland configuration errors:\n%s\n' "$errors" >&2
    exit 1
  fi
fi

printf 'Herdr Drop installed. Try: herdr-drop toggle\n'
