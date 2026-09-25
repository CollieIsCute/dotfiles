# Collie's Dotfiles

## Install

On macOS, Arch Linux, or Ubuntu:

```bash
chezmoi init --apply collieiscute -v
```

Apply local configuration changes:

```bash
chezmoi apply -v
```

### Windows + Arch WSL 2

From a normal PowerShell terminal (with GitHub SSH access already configured):

```powershell
chezmoi init --ssh --apply collieiscute -v
```

This installs Windows dotfiles and Arch on WSL 2. An existing default WSL
distribution must be Arch on WSL 2, with a normal user able to run `sudo`.
Enter the Linux password when prompted. If Windows requests administrator
approval or a reboot, complete it and rerun the same command.

Update both environments from Windows with `chezmoi apply -v`.

Optional: set `CHEZMOI_WSL_USER` to choose the initial Linux username.
For unattended installs, set `CHEZMOI_WSL_PASSWORD`; do not store a real password
in your profile or repo.

To apply only inside WSL:

```sh
chezmoi --source /mnt/c/Users/<user>/.local/share/chezmoi apply
```

## Theme

Change the wallpaper and colors on Linux / macOS, or generate colors on Windows:

```bash
chezmoi theme IMAGE
```

## SketchyBar (macOS)

After the first `chezmoi apply`, AeroSpace opens automatically:

1. Follow the macOS permission prompts. Under **System Settings → Privacy & Security**, allow AeroSpace in **Accessibility** and **Screen & System Audio Recording**. If you previously denied a request, enable it there manually. If launching SketchyBar from a terminal, allow that terminal too.
2. Open CodexBar, enable and sign in to the providers you use, and disable unused providers. Relaunch CodexBar if it was already open during apply.
3. Set **System Settings → Menu Bar → Automatically hide and show the menu bar → Always**.
4. After granting permissions, quit SketchyBar, then quit and reopen AeroSpace. Reloading SketchyBar alone does not apply new permissions.

Daily use:

- **Workspaces:** click a number to switch.
- **GPT / Claude:** hover for detailed usage, left-click for that provider's details, or right-click to refresh.
- **System monitor:** CPU graph → RAM % → GPU graph → GPU shared memory (GiB) → CPU temperature → battery %. Refreshes every 5 seconds; click to open Activity Monitor. On M2 Macs, keep Stats installed for its bundled temperature reader; Stats does not need to be running.
- **Network:** download `↓` and upload `↑` speeds refresh every 5 seconds; click to open Activity Monitor.
- **Input source:** click to open the input-method menu.
- **Volume:** click to toggle mute; scroll to adjust by 3%.
- **Control Center:** press `Fn+C`.
- **App menus:** move the pointer to the top edge or press `Fn+Control+F2`. Move the pointer away after dismissing the menu to restore SketchyBar.

If the input-source icon is missing or incorrect after rearranging native menu-bar items:

```bash
sketchybar --reload
```

If it is still missing, check the permissions above and inspect the available items:

```bash
sb-status-items list
sketchybar --query default_menu_items
```

## Dropbox (Linux)

- On a new machine with `dropbox-cli` installed, run `env -u DISPLAY -u WAYLAND_DISPLAY dropbox-cli start` and open the printed URL.
- Keep `dropbox.service` and `dropbox@USER.service` disabled when using Hyprland's Dropbox startup.

## Noctalia (Linux)

- Run `chezmoi apply` after changing the monitor layout.
- If widget edits in Noctalia's GUI override your dotfiles, remove `[desktop_widgets]` and `[lockscreen_widgets]` from `~/.local/state/noctalia/settings.toml`, or copy those choices into your template before applying.
- Enable live wallpapers through Noctalia's **W Engine** bar widget.

### Display manager recovery (Arch)

- Select **SDDM** during `archinstall`; apply the dotfiles to set up Noctalia Greeter.
- If Noctalia Greeter shows a black screen, switch to a TTY with `Ctrl+Alt+F2` and run:

  ```bash
  sudo systemctl disable --now greetd.service && sudo systemctl enable --now sddm.service
  ```

- If TTY switching does not work, boot with `systemd.unit=multi-user.target` from GRUB, then run the same command.

## Voice dictation

On Arch Linux x86_64, macOS, or Windows x64 with AVX2:

1. Launch OpenWhispr (`openwhispr` on Linux / Windows).
2. Run `asr-mode sensevoice` for CPU-only recognition or `asr-mode qwen-1.7b` for GPU-backed recognition.
3. In OpenWhispr, set Self-Hosted to `http://127.0.0.1:8080/v1` and paste the printed `OpenWhispr Model ID`.
4. Restart OpenWhispr after `chezmoi apply` to load its shortcuts.

- **macOS:** grant Microphone and Accessibility permissions.
- **Windows:** reopen the terminal after applying; install the [Visual C++ x64 runtime](https://learn.microsoft.com/en-us/cpp/windows/latest-supported-vc-redist), allow microphone access, and install a Vulkan GPU driver for Qwen.
- **Linux:** if OpenWhispr 1.9.2 shows a ydotool setup warning, do not add the `input` group or daemon just to dismiss it; `wtype` is already selected.
- Run `asr-mode off` before gaming to stop recognition and release GPU memory. Quit OpenWhispr separately if you also want to disable its UI and shortcut.

## AI extensions

- Add plugins and marketplaces in [`home/.chezmoidata/ai.yaml`](home/.chezmoidata/ai.yaml), then run `chezmoi apply` and restart the affected app.
- Place shared user skills in `~/.agents/skills`.
- Review and trust new Codex hooks manually with `/hooks`.
- For OpenCode's zh-TW linting, install [zhtw-mcp](https://github.com/sysprog21/zhtw-mcp) from source with `make install`; its binary must be at `~/.local/bin/zhtw-mcp`.

## Keymappings

`$SUPER` = Windows / Cmd key. `$ALT` = Option / Meta. `$CTRL` = Control.

### Hyprland (Wayland)

| Bind | Action |
|---|---|
| `SUPER+T` | open Kitty |
| `SUPER+E` | open Nautilus |
| `SUPER+C` | close window |
| `SUPER+M` | exit Hyprland |
| `SUPER+V` | toggle floating |
| hold `SHIFT+F13` | OpenWhispr push-to-talk dictation |
| `SUPER+F13` | OpenWhispr local voice agent |
| `SUPER+P` | pseudotile |
| `SUPER+RETURN` | true fullscreen |
| `SUPER+N` | toggle Noctalia notifications |
| `SUPER+S` | toggle scratchpad workspace |
| `SUPER+SHIFT+S` | move window to scratchpad |
| `SUPER+SPACE` | Noctalia launcher |
| `ALT+L` | Noctalia lock screen |
| `ALT+J` | toggle split |
| `ALT+P` | Noctalia region screenshot → clipboard |
| `CTRL+RETURN` | maximize |
| `SUPER+H/J/K/L` | focus left/down/up/right |
| `SUPER+1..9,0` | switch workspace 1..10 |
| `SUPER+SHIFT+1..9,0` | move window to workspace |
| `SUPER+SHIFT+H/L` | move window to prev/next monitor |
| `SUPER+ALT+H/J/K/L` | swap workspace contents left/down/up/right, keeping workspace numbers fixed |
| `SUPER+scroll` | cycle workspaces |
| `SUPER+LMB/RMB drag` | move/resize floating window |
| `XF86Audio*` | volume / mute / mic mute |
| `XF86MonBrightness*` | screen brightness |

### AeroSpace (macOS)

| Bind | Action |
|---|---|
| hold `Shift+F13` | OpenWhispr push-to-talk dictation |
| `Cmd+F13` | OpenWhispr local voice agent |
| `Cmd+Option+H/J/K/L` | swap workspace windows left/down/up/right, keeping workspace numbers fixed |
| `Cmd+Option+S` | toggle the dedicated `magic` workspace |
| `Cmd+Option+Shift+S` | move window to the `magic` workspace |

### Tmux (prefix = `C-z`)

| Bind | Action |
|---|---|
| `prefix \|` | split horizontal (keep cwd) |
| `prefix -` | split vertical (keep cwd) |
| `prefix v` (copy mode) | begin selection |
| `prefix C-v` (copy mode) | rectangle toggle |
| `prefix y` (copy mode) | copy + cancel |
| `C-←/↓/↑/→` | resize pane (smart-splits) |
| `prefix I` | install plugins (TPM) |
| `prefix U` | update plugins (TPM) |

### Kitty (macOS)

| Bind | Action |
|---|---|
| `Cmd+T` | new tab |
| `Cmd+W` | close tab |
| `Cmd+Shift+]/[` | next / previous tab |
| `Cmd+Shift+→/←` | move tab forward / backward |
| `Cmd+D` | new window (split) |
| `Cmd+Shift+D` | close window |
| `Ctrl+Shift+]/[` | next / previous window |
| `Cmd+Shift+J/K` | scroll line down / up |
| `Cmd+Shift+N/U` | scroll page down / up |
| `Cmd+Shift+Home/End` | scroll to top / bottom |
| `Cmd+C / Cmd+V` | copy / paste |
| `Cmd+Shift+F5` | reload config |
| `Cmd+Shift+F6` | debug config |
| `Ctrl+± / Ctrl+0` | font size + / − / reset |

### Fish aliases

| Alias | Expands to |
|---|---|
| `vi` | `nvim` (when nvim is installed) |
| `buu` | `brew update && brew upgrade -y && fisher update` (macOS only) |
