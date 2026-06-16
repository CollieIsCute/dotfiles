# Noctalia v5 Migration Plan

## Goal

Move the Linux Wayland shell layer to Noctalia v5 while keeping the existing Hyprland setup usable during the transition.

This migration is intentionally split into two phases:

1. Enable Noctalia and route shell-facing actions through it.
2. Remove legacy gadgets only after the new setup has been tested in a real session.

Noctalia v5 is still alpha software, so the first phase keeps the old packages installed as a fallback.

## Phase 1: Enable Noctalia

### Packages

- Add `noctalia-git` to the Arch/CachyOS package list.
- Keep the existing gadget packages installed for now: `waybar`, `swaync`, `rofi`, `hyprpaper`, `hypridle`, `hyprlock`, `hyprshot`, `cliphist`, `swayidle`, and `swaylock`.

### Noctalia Config

- Add `~/.config/noctalia/config.toml` via chezmoi.
- Configure a minimal working shell: bar, widgets, notifications, wallpaper, lock screen, idle behavior, screenshots, and clipboard history.
- Disable telemetry.
- Use the existing wallpaper at `~/.config/wallpapers/xp_wallpaper.jpg`.

### Hyprland Startup

- Keep `fcitx5 -d` in the Hyprland startup hook.
- Replace `waybar`, `hyprpaper`, and `hypridle` startup commands with `noctalia`.
- Keep `blueman-applet` during the first phase.

### Keybind Replacements

- Replace the Rofi launcher bind with `noctalia msg panel-toggle launcher`.
- Replace the SwayNC bind with `noctalia msg panel-toggle control-center notifications`.
- Replace the Hyprlock bind with `noctalia msg session lock`.
- Replace the Hyprshot region screenshot bind with `noctalia msg screenshot-region`.
- Replace `wpctl` volume binds with Noctalia volume IPC.
- Replace `playerctl` media binds with Noctalia media IPC.
- Replace `brightnessctl` brightness binds with Noctalia brightness IPC.

### Feature Mapping

| Current tool | Noctalia replacement |
|---|---|
| `waybar` | Bar widgets: workspaces, tray, media, network, system monitor, volume, battery, clock, session |
| `swaync` | Notification daemon, notification history, Do Not Disturb, Control Center |
| `rofi` | Launcher and window/session providers |
| `hyprpaper` | Wallpaper service and wallpaper picker |
| `hypridle` | Idle behaviors and DPMS actions |
| `hyprlock` | Lock screen and session lock IPC |
| `hyprshot` | Screenshot IPC and screenshot widget behavior |
| `cliphist` | Clipboard history and clipboard panel |

### Idle Behavior

- Recreate the current lock behavior with `noctalia:session lock` at 300 seconds.
- Recreate monitor poweroff with `noctalia:dpms-off` and `noctalia:dpms-on` at 600 seconds.
- Defer the current 480 second brightness reduction because the machine does not currently have `brightnessctl` installed. Add it later through Noctalia brightness IPC if still needed.

### Validation

- Run `chezmoi diff`.
- Run `chezmoi apply --dry-run`.
- Run `noctalia config validate` once `noctalia` is available.
- Test in a real Hyprland session: bar, launcher, notifications, Control Center, lock screen, idle, screenshots, clipboard, volume keys, media keys, and wallpaper.

## Phase 2: Remove Legacy Gadgets

Only do this after Phase 1 has been tested in a real session.

### Package Cleanup

Remove these from the package list:

- `waybar`
- `swaync`
- `rofi`
- `hyprpaper`
- `hypridle`
- `hyprlock`
- `hyprshot`
- `cliphist`
- `swayidle`
- `swaylock`

### Config Cleanup

- Remove `home/dot_config/waybar/`.
- Remove `home/dot_config/swaync/`.
- Remove `home/dot_config/rofi/`.
- Remove `home/dot_config/hypr/hyprpaper.conf`.
- Remove `home/dot_config/hypr/hypridle.conf`.
- Remove `home/dot_config/hypr/hyprlock.conf`.
- Remove the Waybar Catppuccin external theme from `home/.chezmoiexternal.toml.tmpl`.

### Optional Later Cleanup

- Keep `blueman`, `network-manager-applet`, and `pavucontrol` during Phase 1.
- Consider removing them only after Noctalia Bluetooth, Network, and Audio Control Center behavior is confirmed.
- Keep `hyprpolkitagent` until Noctalia's native polkit agent is enabled and verified.

## Rollback

Phase 1 is rollback-friendly because it keeps legacy packages installed. To roll back, remove `noctalia` from the Hyprland startup hook and restore the old `waybar`, `hyprpaper`, and `hypridle` startup commands.
