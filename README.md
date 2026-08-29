# Herdr Drop for Omarchy

A persistent Herdr client in a drop-down Hyprland window. Press `SUPER + A`
to show or hide the same client without starting a new agent. The selected
Herdr view and scrollback stay where you left them.

Version 1.2 adds an optional Shibumi bar button and a live connector that makes
the bar and panel read as one surface while the panel is open. Version 1.3 adds
a sheep icon that reacts with the panel, uses live agent state for its accent
and attention dot, and shows concrete Herdr workspace and agent details on
hover. Version 1.4 distinguishes completed, blocked, and offline states, shows
the two most important agents, and adds a privacy mode for screen sharing.
Version 1.5 owns its Omarchy-to-Herdr theme hook, consumes Herdr events instead
of polling every three seconds, validates the Shibumi host contract, and makes
`doctor` verify the installed connector and its live colors.

The core is an Omarchy and Hyprland integration. The optional bar component is
a Quickshell plugin; the installer still owns the window rule and keybinding
that `omarchy plugin add` intentionally does not manage.

## Requirements

- Omarchy Quattro with Lua-based Hyprland configuration
- [Herdr](https://herdr.dev/) available as `herdr`
- `jq`, `hyprctl`, `omarchy`, and `omarchy-launch-tui`
- Optional connector: the `hancore.shibumi.bar` plugin with its connected-panel
  contract v1 or newer, plus `omarchy-shell` and `socat`

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
5. Installs a theme template and hook, then applies the current Omarchy palette
   to Herdr without replacing Herdr's other settings.
6. Reloads Hyprland and fails if `hyprctl configerrors` reports a problem.

To focus a specific pane when the drop-down client is first created:

```bash
./install.sh --focus-title "Mission Control"
```

The title is matched as plain text. Leave it unset to keep Herdr's current
focus.

### Connect to the Shibumi bar

If Shibumi is your active bar, add the community plugin after installing the
core integration and its connected-panel visual profile:

```bash
./install.sh --shibumi-style
omarchy plugin add https://github.com/lixenstrand/omarchy-herdr-drop-plugin.git --enable
```

The plugin is maintained and released separately at
[omarchy-herdr-drop-plugin](https://github.com/lixenstrand/omarchy-herdr-drop-plugin).
It installs only the Omarchy Shell service and bar widget; this repository's
installer continues to own the command, keybinding, window rules, theme hook,
and the visual profile that gives the panel its 6 px corners, matched top gap,
1 px themed border, 94% opacity, and top-edge animation.

For development or a single-checkout installation, the bundled copy remains
available:

```bash
./install.sh --shibumi
```

The button toggles Herdr Drop. While the panel is visible, Herdr Drop draws the
caret and connector over the real panel border using Omarchy's live popup
background and border theme roles; hiding the panel removes both.
The sheep briefly hops when the panel opens and leaves upward when it closes.
Its accent means a detected Herdr agent is working. A dot means an agent is
done, `!` means an agent is blocked, and a dimmed sheep means the Herdr server
is unavailable. Hovering reports the focused workspace, up to two agents in
priority order with their real terminal tasks, and current totals.
The base installation remains independent of Shibumi. When the bundled plugin
changes, the installer restarts Omarchy Shell so its long-lived service and bar
widget cannot run different versions; an unchanged reinstall only performs a
lightweight plugin rescan.
Herdr status updates arrive through one persistent socket subscription. A
60-second health poll runs while connected; a 15-second fallback is used if
the event stream is unavailable. Hyprland geometry follows compositor events
with a 30-second repair poll.

## Configure

Edit the key, geometry, or animation speed here:

```text
~/.config/hypr/herdr-drop-settings.lua
```

The defaults use 82% of the monitor width, 68% of its height, a 24 px top
margin, and 12 px rounded corners. Border color, border width, opacity, and
special-workspace animation inherit Omarchy unless explicitly overridden.

With `--shibumi`, a small final profile changes the top edge to 39 px, radius
to 6 px, border to 1 px, opacity to 94%, and the animation to enter and leave
through the top edge so the foreign window matches the bar. Removing the
integration restores the user-owned values above.

Set `opacity` to a Hyprland opacity rule such as
`"0.98 override 0.94 override"`, or `border_size` to an integer. Set
`animation_speed` to a number such as `4` to opt into the top-edge slide
animation. Hyprland applies special-workspace animation leaves globally, not
to one named special workspace. The Shibumi profile enables speed `4`.

The optional first-launch pane title lives here as one plain-text line:

```text
~/.config/herdr-drop/config
```

For screen sharing, set `privacyMode` on the widget entry in
`~/.config/omarchy/shell.json`. Status and counts remain visible, but workspace
labels and terminal titles are omitted:

```json
{
  "id": "io.github.lixenstrand.herdr-drop",
  "privacyMode": true
}
```

Set `animateSheep` to `false` in the same entry to keep state colors and badges
without spatial motion.

## Commands

```bash
herdr-drop toggle  # show or hide
herdr-drop open    # always show
herdr-drop hide    # always hide
herdr-drop kill    # close the client; Herdr sessions keep running
herdr-drop doctor  # verify files, contracts, event mode, and live theme colors
herdr-drop version # print the installed version
```

## Uninstall

```bash
./uninstall.sh
```

This removes only symlinks owned by this checkout, the optional Shibumi widget,
and the marked `require` block in `hyprland.lua`. User settings remain in
place. Omarchy Shell restarts after widget removal so no old service stays in
memory. The removed widget directory is kept under
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
