#!/bin/bash
# Install the versioned Herdr Drop integration into user-owned Omarchy config.

set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
USER_HOME="${HERDR_DROP_HOME:-$HOME}"
BIN="${USER_HOME}/.local/bin"
CONFIG_ROOT="${XDG_CONFIG_HOME:-$USER_HOME/.config}"
HYPR="$CONFIG_ROOT/hypr"
HYPRLAND="$HYPR/hyprland.lua"
DROP_CONFIG="$CONFIG_ROOT/herdr-drop/config"
PLUGIN_ROOT="$CONFIG_ROOT/omarchy/plugins"
SHELL_CONFIG="$CONFIG_ROOT/omarchy/shell.json"
SHIBUMI_BAR_ID="hancore.shibumi.bar"
SHIBUMI_WIDGET_ID="io.github.lixenstrand.herdr-drop"
SHIBUMI_PLUGIN="$SRC/integrations/shibumi/plugin"
SHIBUMI_PLUGIN_TARGET="$PLUGIN_ROOT/$SHIBUMI_WIDGET_ID"
SHIBUMI_PROFILE="$SRC/integrations/shibumi/herdr-drop-integration.lua"
SHIBUMI_HOST_CONTRACT_VERSION=1
THEME_TEMPLATE="$SRC/integrations/omarchy/themed/herdr.toml.tpl"
THEME_HOOK="$SRC/integrations/omarchy/hooks/herdr-theme"
THEMED_ROOT="$CONFIG_ROOT/omarchy/themed"
THEME_HOOK_ROOT="$CONFIG_ROOT/omarchy/hooks/theme-set.d"
shibumi_plugin_changed=0
STAMP="$(date +%s)"
FOCUS_TITLE=""
FOCUS_TITLE_SET=0
RELOAD=1
SHIBUMI=0

usage() {
  cat <<'USAGE'
Usage: ./install.sh [--focus-title TEXT] [--shibumi] [--no-reload]

  --focus-title TEXT  Focus the first Herdr pane whose title contains TEXT
                      when the drop-down client is first created.
  --shibumi           Add the Herdr bar button and connected-panel styling for
                      the hancore.shibumi.bar plugin.
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
  --shibumi)
    SHIBUMI=1
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

if (( SHIBUMI )); then
  for command_name in omarchy-shell socat; do
    command -v "$command_name" >/dev/null 2>&1 || {
      echo "Missing required command for --shibumi: $command_name" >&2
      exit 1
    }
  done
  [[ -f $SHELL_CONFIG ]] || {
    echo "Omarchy shell configuration not found: $SHELL_CONFIG" >&2
    exit 1
  }
  active_bar="$(jq -r '.bar.id // "omarchy.bar"' "$SHELL_CONFIG")"
  [[ $active_bar == "$SHIBUMI_BAR_ID" ]] || {
    echo "--shibumi requires the active bar to be $SHIBUMI_BAR_ID (found: $active_bar)" >&2
    exit 1
  }
  shibumi_host="$PLUGIN_ROOT/$SHIBUMI_BAR_ID/Bar.qml"
  [[ -f $shibumi_host ]] || {
    echo "Shibumi bar entry point not found: $shibumi_host" >&2
    exit 1
  }
  shibumi_contract_version="$(sed -nE \
    's/.*property[[:space:]]+int[[:space:]]+shibumiHostContractVersion[[:space:]]*:[[:space:]]*([0-9]+).*/\1/p' \
    "$shibumi_host" | head -n 1)"
  if [[ ! $shibumi_contract_version =~ ^[0-9]+$ ]] \
    || (( shibumi_contract_version < SHIBUMI_HOST_CONTRACT_VERSION )); then
    echo "Incompatible Shibumi connected-panel contract: need version $SHIBUMI_HOST_CONTRACT_VERSION or newer, found ${shibumi_contract_version:-none}" >&2
    exit 1
  fi
  for api_function in publishConnectedPanel clearConnectedPanel requestPopout releasePopout; do
    grep -qF "function $api_function" "$shibumi_host" || {
      echo "Incompatible Shibumi contract v$shibumi_contract_version: missing $api_function" >&2
      exit 1
    }
  done
fi

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

mkdir -p "$BIN" "$HYPR" "$(dirname "$DROP_CONFIG")" \
  "$THEMED_ROOT" "$THEME_HOOK_ROOT"

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
  if [[ -d $target && ! -L $target ]]; then
    echo "Refusing to replace directory: $target" >&2
    exit 1
  fi
  backup "$target"
  ln -sfn -- "$source" "$target"
}

install_shibumi_plugin() {
  local target="$SHIBUMI_PLUGIN_TARGET"
  local marker=".herdr-drop-owned"
  local plugin_files=(manifest.json BarWidget.qml Service.qml Status.js ThemedConnector.qml "$marker")
  local matches=1 file backup_root backup_target

  if [[ -L $target ]]; then
    if [[ $(readlink -f -- "$target") == $(readlink -f -- "$SHIBUMI_PLUGIN") ]]; then
      unlink -- "$target"
    else
      echo "Refusing to replace plugin link not owned by this checkout: $target" >&2
      exit 1
    fi
  elif [[ -e $target ]]; then
    [[ -d $target && -f $target/$marker ]] \
      && grep -qFx -- "$SHIBUMI_WIDGET_ID" "$target/$marker" || {
        echo "Refusing to replace plugin directory not owned by Herdr Drop: $target" >&2
        exit 1
      }
    for file in "${plugin_files[@]}"; do
      if ! cmp -s -- "$SHIBUMI_PLUGIN/$file" "$target/$file"; then
        matches=0
        break
      fi
    done
    if (( matches )); then return 0; fi
    backup_root="$CONFIG_ROOT/herdr-drop/backups"
    mkdir -p "$backup_root"
    backup_target="$backup_root/shibumi-plugin.$STAMP"
    while [[ -e $backup_target ]]; do backup_target="$backup_target.1"; done
    cp -a -- "$target" "$backup_target"
  fi

  mkdir -p "$target"
  for file in "${plugin_files[@]}"; do
    install -m 644 "$SHIBUMI_PLUGIN/$file" "$target/$file"
  done
  shibumi_plugin_changed=1
}

link_file "$SRC/bin/herdr-drop" "$BIN/herdr-drop"
link_file "$SRC/hypr/herdr-drop.lua" "$HYPR/herdr-drop.lua"
link_file "$THEME_TEMPLATE" "$THEMED_ROOT/herdr-drop.toml.tpl"
link_file "$THEME_HOOK" "$THEME_HOOK_ROOT/herdr-drop-theme"

# Remove only the unpublished v1.5 development names owned by this checkout.
# The public names are unique so another Herdr theme integration is untouched.
for legacy_target in "$THEMED_ROOT/herdr.toml.tpl" \
  "$THEME_HOOK_ROOT/herdr-theme"; do
  if [[ -L $legacy_target ]] \
    && { [[ $(readlink -f -- "$legacy_target") == $(readlink -f -- "$THEME_TEMPLATE") ]] \
      || [[ $(readlink -f -- "$legacy_target") == $(readlink -f -- "$THEME_HOOK") ]]; }; then
    unlink -- "$legacy_target"
  fi
done

# Apply the current palette immediately. Later theme changes call the same
# hook through Omarchy's theme-set lifecycle.
HOME="$USER_HOME" HERDR_CONFIG="$CONFIG_ROOT/herdr/config.toml" \
  OMARCHY_THEME_DIR="$USER_HOME/.local/state/omarchy/current/theme" \
  "$THEME_HOOK" || {
  echo "Could not synchronize Herdr with the active Omarchy theme" >&2
  exit 1
}

if (( SHIBUMI )); then
  mkdir -p "$PLUGIN_ROOT"
  install_shibumi_plugin
  link_file "$SHIBUMI_PROFILE" "$HYPR/herdr-drop-integration.lua"
fi

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

if (( SHIBUMI )); then
  # A plugin rescan refreshes widgets but keeps an already-instantiated
  # Service.qml alive. Restart only when the owned payload changed so service
  # and widget code always come from the same version.
  if (( shibumi_plugin_changed )); then
    omarchy restart shell >/dev/null
  else
    omarchy-shell shell rescanPlugins >/dev/null
  fi
  omarchy bar put "$SHIBUMI_WIDGET_ID" --section center >/dev/null
fi

if (( SHIBUMI )); then
  printf 'Herdr Drop and its Shibumi connector are installed. Try: herdr-drop toggle\n'
else
  printf 'Herdr Drop installed. Try: herdr-drop toggle\n'
fi
