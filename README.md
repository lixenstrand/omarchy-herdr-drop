# Herdr Drop for Omarchy

A persistent Herdr client in a drop-down Hyprland window. Press `SUPER + A`
to show or hide the same client without starting a new agent. The selected
Herdr view and scrollback stay where you left them.

Version 1.2 adds an optional Shibumi bar button and a live connector that makes
the bar and panel read as one surface while the panel is open.

The core is an Omarchy and Hyprland integration. The optional bar component is
a Quickshell plugin; the installer still owns the window rule and keybinding
that `omarchy plugin add` intentionally does not manage.

## Requirements

- Omarchy Quattro with Lua-based Hyprland configuration
- [Herdr](https://herdr.dev/) available as `herdr`
- `jq`, `hyprctl`, `omarchy`, and `omarchy-launch-tui`
- Optional connector: the `hancore.shibumi.bar` plugin with its connected-panel
  API

## Install

Review the scripts, clone the repository, and run the installer:

```bash
git clone https://github.com/lixenstrand/omarchy-herdr-drop.git
cd omarchy-herdr-drop
./install.sh
```

The installer:

1. Reports the current owner of `SUPER + A` before replacing it.
2. Backs up every existing file it replaces.
3. Symlinks the versioned command and Hyprland module.
4. Creates user-owned settings without overwriting them on later runs.
5. Reloads Hyprland and fails if `hyprctl configerrors` reports a problem.

To focus a specific pane when the drop-down client is first created:

```bash
./install.sh --focus-title "Mission Control"
```

The title is matched as plain text. Leave it unset to keep Herdr's current
focus.

### Connect to the Shibumi bar

If Shibumi is your active bar, install the bar button and matching panel
profile too:

```bash
./install.sh --shibumi
```

The button toggles Herdr Drop. While the panel is visible, Shibumi draws the
caret and connector over the real panel border; hiding the panel removes both.
The QML plugin is installed as an owned directory because Qt rejects a whole
plugin directory reached through a symlink. The base installation remains
independent of Shibumi.

## Configure

Edit the key, geometry, or animation speed here:

```text
~/.config/hypr/herdr-drop-settings.lua
```

The defaults use 82% of the monitor width, 68% of its height, a 24 px top
margin, and 12 px rounded corners. Border color, border width, opacity, and
special-workspace animation inherit Omarchy unless explicitly overridden.

With `--shibumi`, a small final profile changes the top edge to 39 px, radius
to 6 px, border to 1 px, and opacity to 94% so the foreign window matches the
bar. Removing the integration restores the user-owned values above.

Set `opacity` to a Hyprland opacity rule such as
`"0.98 override 0.94 override"`, or `border_size` to an integer. Set
`animation_speed` to a number such as `4` to opt into the slide animation.
Hyprland applies special-workspace animation leaves globally, not to one named
special workspace.

The optional first-launch pane title lives here as one plain-text line:

```text
~/.config/herdr-drop/config
```

## Commands

```bash
herdr-drop toggle  # show or hide
herdr-drop open    # always show
herdr-drop hide    # always hide
herdr-drop kill    # close the client; Herdr sessions keep running
herdr-drop doctor  # verify the installation and active Hyprland config
herdr-drop version # print the installed version
```

## Uninstall

```bash
./uninstall.sh
```

This removes only symlinks owned by this checkout, the optional Shibumi widget,
and the marked `require` block in `hyprland.lua`. User settings remain in
place. The removed widget directory is kept under
`~/.config/herdr-drop/backups/`. To remove user settings too:

```bash
./uninstall.sh --purge
```

## Test

```bash
./test/run
```

## Security

The installer modifies only files owned by the current user. It never invokes
`sudo`, `pkexec`, `curl`, or a remote installer. Review the repository before
running it; the installed command can execute `herdr`, `hyprctl`, `jq`, and
`omarchy-launch-tui` as your user.

## License

MIT
