#!/bin/bash
# Remove only the Herdr Drop files owned by this checkout.

set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
USER_HOME="${HERDR_DROP_HOME:-$HOME}"
BIN="${USER_HOME}/.local/bin"
CONFIG_ROOT="${XDG_CONFIG_HOME:-$USER_HOME/.config}"
HYPR="$CONFIG_ROOT/hypr"
HYPRLAND="$HYPR/hyprland.lua"
DROP_CONFIG="$CONFIG_ROOT/herdr-drop/config"
PLUGIN_ROOT="$CONFIG_ROOT/omarchy/plugins"
SHIBUMI_WIDGET_ID="io.github.lixenstrand.herdr-drop"
SHIBUMI_PLUGIN="$SRC/integrations/shibumi/plugin"
SHIBUMI_PLUGIN_TARGET="$PLUGIN_ROOT/$SHIBUMI_WIDGET_ID"
SHIBUMI_PROFILE="$SRC/integrations/shibumi/herdr-drop-integration.lua"
THEME_TEMPLATE="$SRC/integrations/omarchy/themed/herdr.toml.tpl"
THEME_HOOK="$SRC/integrations/omarchy/hooks/herdr-theme"
THEMED_ROOT="$CONFIG_ROOT/omarchy/themed"
THEME_HOOK_ROOT="$CONFIG_ROOT/omarchy/hooks/theme-set.d"
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
remove_owned_link "$THEMED_ROOT/herdr-drop.toml.tpl" "$THEME_TEMPLATE"
remove_owned_link "$THEME_HOOK_ROOT/herdr-drop-theme" "$THEME_HOOK"

shibumi_owned=0
shibumi_is_directory=0
if [[ -L $SHIBUMI_PLUGIN_TARGET ]] \
  && [[ $(readlink -f -- "$SHIBUMI_PLUGIN_TARGET") == $(readlink -f -- "$SHIBUMI_PLUGIN") ]]; then
  shibumi_owned=1
elif [[ -d $SHIBUMI_PLUGIN_TARGET && ! -L $SHIBUMI_PLUGIN_TARGET ]] \
  && [[ -f $SHIBUMI_PLUGIN_TARGET/.herdr-drop-owned ]] \
  && grep -qFx -- "$SHIBUMI_WIDGET_ID" "$SHIBUMI_PLUGIN_TARGET/.herdr-drop-owned"; then
  shibumi_owned=1
  shibumi_is_directory=1
fi

if (( shibumi_owned )); then
  if command -v omarchy >/dev/null 2>&1 \
    && command -v omarchy-shell >/dev/null 2>&1; then
    if ! omarchy plugin disable "$SHIBUMI_WIDGET_ID" >/dev/null 2>&1; then
      echo "Could not remove the Herdr widget from the running bar; its files will still be removed." >&2
    fi
  fi
  if (( shibumi_is_directory )); then
    plugin_backup_root="$CONFIG_ROOT/herdr-drop/backups"
    mkdir -p "$plugin_backup_root"
    plugin_backup_target="$plugin_backup_root/shibumi-plugin.uninstalled.$STAMP"
    while [[ -e $plugin_backup_target ]]; do
      plugin_backup_target="$plugin_backup_target.1"
    done
    mv -- "$SHIBUMI_PLUGIN_TARGET" "$plugin_backup_target"
  else
    unlink -- "$SHIBUMI_PLUGIN_TARGET"
  fi
  # A rescan does not destroy an already-instantiated plugin service. Restart
  # the shell after removal so no stale connector survives the uninstall.
  if command -v omarchy >/dev/null 2>&1; then
    omarchy restart shell >/dev/null 2>&1 || true
  elif command -v omarchy-shell >/dev/null 2>&1; then
    omarchy-shell shell rescanPlugins >/dev/null 2>&1 || true
  fi
elif [[ -e $SHIBUMI_PLUGIN_TARGET || -L $SHIBUMI_PLUGIN_TARGET ]]; then
  printf 'Preserved plugin not owned by this checkout: %s\n' "$SHIBUMI_PLUGIN_TARGET" >&2
fi

remove_owned_link "$HYPR/herdr-drop-integration.lua" "$SHIBUMI_PROFILE"

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
