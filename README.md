# Collie's Dotfiles

[![CI](https://github.com/CollieIsCute/dotfiles/actions/workflows/test-distros.yaml/badge.svg?branch=main)](https://github.com/CollieIsCute/dotfiles/actions/workflows/test-distros.yaml)
![macOS](https://img.shields.io/badge/macOS-Homebrew-000?logo=apple&logoColor=white)
![Arch](https://img.shields.io/badge/Arch-pacman%20%2B%20paru-1793D1?logo=archlinux&logoColor=white)
![Ubuntu](https://img.shields.io/badge/Ubuntu-apt-E95420?logo=ubuntu&logoColor=white)
![Debian](https://img.shields.io/badge/Debian-apt-A81D33?logo=debian&logoColor=white)
![Mint](https://img.shields.io/badge/Linux%20Mint-apt-87CF3E?logo=linuxmint&logoColor=white)
![Windows](https://img.shields.io/badge/Windows-Scoop-0078D4?logo=windows&logoColor=white)

Personal dotfiles managed with [chezmoi](https://chezmoi.io). One repo, several machines.

## Install

```bash
chezmoi init --apply collieiscute -v
```

## Supported platforms

| OS | Package manager | Status |
|---|---|---|
| macOS | Homebrew | daily-driven |
| Arch | pacman + paru | daily-driven |
| Ubuntu / Debian / Linux Mint | apt | CI-tested only |
| Windows | Scoop | CI-tested only |

## Custom touches worth knowing

### Theme

- Linux uses Noctalia's wallpaper-derived **light** palette; macOS and Windows use Matugen with the same per-app theme paths.
- Generated app themes stay outside chezmoi. [`.chezmoiexternal.toml`](home/.chezmoiexternal.toml) only pins the Matugen template inputs.
- Fish inherits the terminal ANSI palette; cursor themes stay independent.
- Font: **JetBrainsMono Nerd Font** across every terminal / bar / lock screen.

### chezmoi quirks I keep tripping over (that this repo handles)

- `run_onchange_*` scripts only re-run when their **rendered** content changes. Manifest files (`fish_plugins`, `Brewfile`) that aren't templated into the script bodies don't trigger reruns. Both are pinned via embedded sha256 hash comments — see `run_onchange_after_1-setup-fish-and-its-plugins.sh.tmpl` and `install-packages_darwin.tmpl`.
- All apt-based distros share `.packages.ubuntu.apt` and the lazygit-from-GitHub fallback (lazygit isn't in Ubuntu apt).
- Fonts use the Nerd Font patched family (`JetBrainsMono Nerd Font`), not the un-patched JetBrains Mono — drop that distinction and bar icons disappear.

### Dropbox

- Hyprland starts `dropbox-cli` headlessly when the command is installed (currently via AUR on Arch); other Linux hosts skip it. On a new machine, run `env -u DISPLAY -u WAYLAND_DISPLAY dropbox-cli start` in a terminal and open the printed URL.
- Keep `dropbox.service` and `dropbox@USER.service` disabled; Hyprland is the only startup path.

### Tmux

- Prefix is `C-z` (so `C-b` stays free for vim).
- Splits: `prefix |` (horizontal), `prefix -` (vertical), inheriting the current pane's path.
- `set-clipboard on` + `allow-passthrough` → OSC 52 yank works over SSH without X11 forwarding.
- Sessions auto-restore via tmux-resurrect + tmux-continuum on tmux start.

### Kitty

- Used on macOS specifically because [AeroSpace](https://github.com/nikitabobko/AeroSpace) tiles each Ghostty native tab as a separate window — Kitty's custom tab bar appears as a single AXWindow.
- `cmd+option`/Alt key bindings deliberately avoided (macOS 26 Tahoe intercepts them).
- Kitty, Alacritty, and Ghostty point at the fixed `noctalia` theme path; Noctalia or Matugen owns the generated colors.

### Hyprland

- Desc-keyed Lua `hl.monitor(...)` overrides plus a fallback that selects the highest resolution and refresh rate available at that resolution.
- Cursor: Catppuccin Mocha Teal (Hyprcursor) with Catppuccin Mocha Green as XCursor fallback.
- Electron / fcitx5 / Qt integration env vars set centrally. Noctalia applies GTK light mode and generated GTK/Qt colors through its built-in templates.
- Noctalia v5 owns the desktop shell layer (bar, launcher, notifications, wallpaper, lock screen, idle, screenshots, clipboard).
- Noctalia Shell is installed on Arch and Ubuntu. Noctalia Greeter stays Arch-only; Ubuntu keeps SDDM.
- Wallpapers are deployed by chezmoi to `~/.config/wallpapers`; Noctalia reads that path directly.
- Noctalia is the Linux wallpaper/theme owner for apps with built-in adapters. App integrations write generated theme files and reload apps; chezmoi keeps their main configs pre-aligned so post-hooks do not cause drift.
- Noctalia desktop/lockscreen widget placement is generated from monitor roles and ratios in `20-widgets.generated.toml.tmpl`; run `chezmoi apply` after changing the monitor layout.
- If widgets are edited in Noctalia's GUI, remove `[desktop_widgets]` and `[lockscreen_widgets]` from `~/.local/state/noctalia/settings.toml` or fold the new ratios back into the template; state overrides win over declarative config.
- Wallpaper Engine is opt-in through Noctalia's W Engine bar widget; palettes sync through Noctalia and Steam Workshop selections stay machine-local.

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
| tap `F13` | OpenWhispr dictation toggle |
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

Voice dictation uses OpenWhispr on Arch Linux x86_64 and macOS. Select
`asr-mode sensevoice` for the CPU-only SenseVoice model or `asr-mode qwen-1.7b`
for the GPU-backed Qwen3-ASR model; missing models download only when selected.
Models use `${XDG_CACHE_HOME:-$HOME/.cache}/crispasr` on Linux and
`${XDG_CACHE_HOME:-$HOME/Library/Caches}/crispasr` on macOS.
Run `asr-mode off` before gaming to stop CrispASR, close port 8080, and release
its GPU memory. OpenWhispr remains in the tray; quit it separately when its UI
and shortcut are not needed.

For first-time OpenWhispr setup, run `asr-mode qwen-1.7b`, then set Self-Hosted
to `http://127.0.0.1:8080/v1` and paste the printed `OpenWhispr Model ID`. Each
successful model switch prints its current absolute path for later connection
tests. Use F13 tap mode. Linux uses its native Hyprland binding and `wtype`;
macOS requires Microphone and Accessibility access. OpenWhispr 1.9.2 may still
show a ydotool setup warning on Linux; `wtype` is already preferred, so do not
add the `input` group or daemon just to dismiss it.

### AeroSpace (macOS)

| Bind | Action |
|---|---|
| tap `F13` | OpenWhispr dictation toggle |
| `Cmd+Option+H/J/K/L` | swap workspace windows left/down/up/right, keeping workspace numbers fixed |
| `Cmd+Option+S` | toggle the dedicated `magic` workspace |
| `Cmd+Option+Shift+S` | move window to the `magic` workspace |

AeroSpace restores the swapped root layouts and window states where possible; its CLI cannot reconstruct nested container geometry.

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

## Tools

### Shell / multiplexer

- [`fish`](https://fishshell.com) — primary shell.
- [`tmux`](https://github.com/tmux/tmux) — primary multiplexer.
- [`zellij`](https://zellij.dev) — secondary multiplexer using the generated Noctalia-compatible theme.

### Editor

- [`neovim`](https://github.com/neovim/neovim) — LazyVim distro on top.

### Terminals

- [`kitty`](https://sw.kovidgoyal.net/kitty/) — macOS daily driver (AeroSpace-friendly tabs).
- [`wezterm`](https://wezterm.org) — cross-platform fallback.
- [`ghostty`](https://ghostty.org) — newer GPU terminal using the generated Noctalia-compatible theme.
- [`alacritty`](https://github.com/alacritty/alacritty) — minimal GPU terminal.

### Wayland stack (Hyprland)

- [`hyprland`](https://hyprland.org) — Wayland compositor.
- [`noctalia`](https://github.com/noctalia-dev/noctalia) — desktop shell: bar, launcher, notifications, wallpaper, lock screen, idle behavior, screenshots, clipboard, and control center.
- [`linux-wallpaperengine`](https://github.com/Almamu/linux-wallpaperengine) — opt-in live wallpapers from Steam Wallpaper Engine assets on Hyprland.
- [`sddm`](https://github.com/sddm/sddm) — bootstrap and fallback display manager for fresh Arch installs.
- [`greetd`](https://git.sr.ht/~kennylevinsen/greetd) + [`Noctalia Greeter`](https://github.com/noctalia-dev/noctalia-greeter) — final Wayland login greeter after AUR packages are installed.
- [`fcitx5`](https://github.com/fcitx/fcitx5) + chewing — Chinese input.

### Display manager bootstrap and recovery

- Fresh Arch installs should use `SDDM` from `archinstall` first; chezmoi switches to `greetd` only after `noctalia-greeter-session` is installed and setup succeeds.
- `SDDM` stays installed as the fallback display manager.
- The switch script only enables/disables services; it does not stop/start the current graphical session.
- If Noctalia Greeter shows a black screen, switch to a TTY with `Ctrl+Alt+F2` and run `sudo systemctl disable --now greetd.service && sudo systemctl enable --now sddm.service`.
- If TTY switching does not work, boot with `systemd.unit=multi-user.target` from GRUB, then run the same service switch.

### macOS extras

- [`aerospace`](https://github.com/nikitabobko/AeroSpace) — tiling WM.
- [`karabiner-elements`](https://karabiner-elements.pqrs.org) — keyboard remapper.
- Desktop wallpaper is deployed by chezmoi to `~/.config/wallpapers`; `run_onchange_after_6-apply-theme.sh.tmpl` applies the initial wallpaper and Matugen palette, and `chezmoi theme [IMAGE]` changes both later.

### CLI tooling

- File / dir: [`eza`](https://github.com/eza-community/eza), [`fd`](https://github.com/sharkdp/fd), [`ripgrep`](https://github.com/BurntSushi/ripgrep), [`bat`](https://github.com/sharkdp/bat), [`zoxide`](https://github.com/ajeetdsouza/zoxide), [`fzf`](https://github.com/junegunn/fzf).
- System info: [`btop`](https://github.com/aristocratos/btop), [`fastfetch`](https://github.com/fastfetch-cli/fastfetch).
- Git: [`lazygit`](https://github.com/jesseduffield/lazygit), [`tig`](https://github.com/jonas/tig), [`gh`](https://cli.github.com), [`glab`](https://gitlab.com/gitlab-org/cli), [`onefetch`](https://github.com/o2sh/onefetch).
- Build / dev: [`gnu-tar`](https://www.gnu.org/software/tar/), [`bear`](https://github.com/rizsotto/Bear), [`cmake`](https://cmake.org), [`mold`](https://github.com/rui314/mold), [`ninja`](https://ninja-build.org), [`llvm`](https://llvm.org), [`clang-format`](https://clang.llvm.org/docs/ClangFormat.html), [`cppcheck`](https://cppcheck.sourceforge.io), [`uv`](https://github.com/astral-sh/uv).
- Containers: macOS Apple silicon [`container`](https://github.com/apple/container) + third-party [`container-compose`](https://github.com/Mcrich23/Container-Compose); Linux [`podman`](https://podman.io).
- Docs: [`hugo`](https://gohugo.io), [`typst`](https://typst.app), [`tldr`](https://tldr.sh).
- OpenCode zh-TW linting: [`zhtw-mcp`](https://github.com/sysprog21/zhtw-mcp) is configured as a local MCP server at `~/.local/bin/zhtw-mcp`. Until upstream publishes releases, install it from source with `make install` so OpenCode can use the fixed binary path.
- OpenCode Claude Code plugin: [`@khalilgharbaoui/opencode-claude-code-plugin`](https://github.com/khalilgharbaoui/opencode-claude-code-plugin) is loaded through OpenCode's native npm plugin support; after changing the plugin list, run `chezmoi apply /home/collie/.config/opencode/opencode.json` and restart OpenCode.

### AI extensions

- [`home/.chezmoidata/ai.yaml`](home/.chezmoidata/ai.yaml) is the single inventory for plugins and marketplaces; add entries there without editing templates.
- Claude Code and Codex update configured marketplace plugins with their native startup updaters.
- OpenCode installs configured npm plugins when its generated cache is missing; remove that cache before startup to fetch newer versions.
- Shared user skills live in `~/.agents/skills`, which Codex and OpenCode discover natively.
- `run_after_5-sync-ai-extensions.sh.tmpl` bootstraps missing Codex plugins.
- Review and trust new Codex hooks manually with `/hooks`.

### Fish plugins (managed by [`fisher`](https://github.com/jorgebucaran/fisher))

- `edc/bass` — run bash scripts in fish.
- `jorgebucaran/nvm.fish` — Node version manager.
- `patrickf1/fzf.fish` — fzf integrations.
- `pure-fish/pure` — minimal prompt.

### Tmux plugins (managed by [`TPM`](https://github.com/tmux-plugins/tpm))

- `mrjones2014/smart-splits.nvim` — `Ctrl+Arrow` resize, plays nice with neovim.
- `tmux-plugins/tmux-sensible` — sensible defaults.
- `tmux-plugins/tmux-continuum` — auto-save/restore on start.
- `tmux-plugins/tmux-resurrect` — manual save/restore + nvim session capture.

### Neovim — LazyVim core extras

- `zbirenbaum/copilot.lua` — Copilot.
- `giuxtaposition/blink-cmp-copilot` — Copilot source for blink.cmp.
- `neovim/nvim-lspconfig` + `p00f/clangd_extensions.nvim` — LSP, with extra clangd polish.
- `nvim-treesitter/nvim-treesitter` — syntax.
- `ibhagwan/fzf-lua` — fuzzy finder.
- `sphamba/smear-cursor.nvim` — animated cursor.
- `folke/snacks.nvim` — utility collection.

## Layout

```
home/                            # chezmoi source root (.chezmoiroot=home)
├── .chezmoidata/packages.yaml   # canonical package list (paru + apt)
├── .chezmoiexternal.toml        # pinned external template inputs
├── .chezmoiscripts/             # run_once / run_onchange bootstrap
├── .chezmoitemplates/           # macOS install template (Brewfile pass-thru)
└── dot_config/                  # → ~/.config/...
```
