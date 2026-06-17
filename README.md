# Collie's Dotfiles

[![CI](https://github.com/CollieIsCute/dotfiles/actions/workflows/test-distros.yaml/badge.svg?branch=main)](https://github.com/CollieIsCute/dotfiles/actions/workflows/test-distros.yaml)
![macOS](https://img.shields.io/badge/macOS-Homebrew-000?logo=apple&logoColor=white)
![Arch](https://img.shields.io/badge/Arch-pacman%20%2B%20paru-1793D1?logo=archlinux&logoColor=white)
![Ubuntu](https://img.shields.io/badge/Ubuntu-apt-E95420?logo=ubuntu&logoColor=white)
![Debian](https://img.shields.io/badge/Debian-apt-A81D33?logo=debian&logoColor=white)
![Mint](https://img.shields.io/badge/Linux%20Mint-apt-87CF3E?logo=linuxmint&logoColor=white)

Personal dotfiles managed with [chezmoi](https://chezmoi.io). One repo, several machines.

## Install

```bash
chezmoi init --apply collieiscute -v
```

## Supported platforms

| OS | Package manager | Status |
|---|---|---|
| macOS | Homebrew | daily-driven |
| Arch / CachyOS | pacman + paru | daily-driven |
| Ubuntu / Debian / Linux Mint | apt | CI-tested only |

## Custom touches worth knowing

### Theme

- **Catppuccin** everywhere. Mocha by default; kitty uses **Macchiato**; Noctalia uses its built-in **Catppuccin** palette.
- Theme files for kitty and alacritty are pulled from the upstream `catppuccin/*` repos via [`.chezmoiexternal.toml.tmpl`](home/.chezmoiexternal.toml.tmpl) with `refreshPeriod = "168h"` — so they auto-update weekly without manual sync.
- Font: **JetBrainsMono Nerd Font** across every terminal / bar / lock screen.

### Per-host config switch

Two Hyprland machines (home + office) share one config but pin different monitors to ws1/2/3. Office hosts get desc-keyed workspace rules; home hosts use Hyprland's default per-monitor assignment (which already gives 1/2/3) — hand-rolled rules would otherwise reserve those slots even when the matching monitor isn't connected (see `hyprland.lua.tmpl` head comment for the underlying bug).

To mark a machine as office: edit `~/.config/chezmoi/chezmoi.toml` →

```toml
[data]
  location = "office"
```

Then `chezmoi apply`.

### chezmoi quirks I keep tripping over (that this repo handles)

- `run_onchange_*` scripts only re-run when their **rendered** content changes. Manifest files (`fish_plugins`, `Brewfile`) that aren't templated into the script bodies don't trigger reruns. Both are pinned via embedded sha256 hash comments — see `run_onchange_after_1-setup-fish-and-its-plugins.sh.tmpl` and `install-packages_darwin.tmpl`.
- All apt-based distros share `.packages.ubuntu.apt` and the lazygit-from-GitHub fallback (lazygit isn't in Ubuntu apt).
- Fonts use the Nerd Font patched family (`JetBrainsMono Nerd Font`), not the un-patched JetBrains Mono — drop that distinction and bar icons disappear.

### systemd-boot opt-in

The systemd-boot setup script is disabled by default so a normal `chezmoi apply` never rewrites bootloader state.

To render `/boot/loader` config without installing the bootloader:

```bash
CHEZMOI_SYSTEMD_BOOT=1 chezmoi apply
```

To also run `bootctl install` and enable `systemd-boot-update.service`:

```bash
CHEZMOI_SYSTEMD_BOOT_INSTALL=1 chezmoi apply
```

Persistent per-host settings can live in `~/.config/chezmoi/chezmoi.toml`:

```toml
[data.systemdBoot]
  enabled = true
  install = false
  rebootForBitlocker = false
```

The script auto-detects the kernel, initramfs, microcode image, and current kernel command line. Before installing systemd-boot it saves the existing fallback EFI loader to `/boot/EFI/saved-fallback/BOOTX64.EFI` and adds a `previous-fallback.conf` entry when that backup exists.

### Tmux

- Prefix is `C-z` (so `C-b` stays free for vim).
- Splits: `prefix |` (horizontal), `prefix -` (vertical), inheriting the current pane's path.
- `set-clipboard on` + `allow-passthrough` → OSC 52 yank works over SSH without X11 forwarding.
- Sessions auto-restore via tmux-resurrect + tmux-continuum on tmux start.

### Kitty (macOS)

- Used on macOS specifically because [AeroSpace](https://github.com/nikitabobko/AeroSpace) tiles each Ghostty native tab as a separate window — Kitty's custom tab bar appears as a single AXWindow.
- `cmd+option`/Alt key bindings deliberately avoided (macOS 26 Tahoe intercepts them).

### Hyprland

- 6 Lua `hl.monitor(...)` rules (3 home + 3 office) — desc-keyed so the right machine picks the right monitors automatically.
- Cursor: Catppuccin Mocha Teal (Hyprcursor) with Catppuccin Mocha Green as XCursor fallback.
- Electron / fcitx5 / GTK theming env vars set centrally.
- Noctalia v5 owns the desktop shell layer (bar, launcher, notifications, wallpaper, lock screen, idle, screenshots, clipboard).
- Wallpapers are deployed by chezmoi to `~/.config/wallpapers`; Noctalia reads that path directly.

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
| `SUPER+scroll` | cycle workspaces |
| `SUPER+LMB/RMB drag` | move/resize floating window |
| `XF86Audio*` | volume / mute / mic mute |
| `XF86MonBrightness*` | screen brightness |

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
| `buu` | `brew update --auto-update && brew upgrade && fisher update` (macOS only) |

## Tools

### Shell / multiplexer

- [`fish`](https://fishshell.com) — primary shell.
- [`tmux`](https://github.com/tmux/tmux) — primary multiplexer.
- [`zellij`](https://zellij.dev) — secondary multiplexer (Catppuccin Mocha built-in theme).

### Editor

- [`neovim`](https://github.com/neovim/neovim) — LazyVim distro on top.

### Terminals

- [`kitty`](https://sw.kovidgoyal.net/kitty/) — macOS daily driver (AeroSpace-friendly tabs).
- [`wezterm`](https://wezterm.org) — cross-platform fallback.
- [`ghostty`](https://ghostty.org) — newer GPU terminal, Catppuccin Mocha.
- [`alacritty`](https://github.com/alacritty/alacritty) — minimal GPU terminal.

### Wayland stack (Hyprland)

- [`hyprland`](https://hyprland.org) — Wayland compositor.
- [`noctalia`](https://github.com/noctalia-dev/noctalia) — desktop shell: bar, launcher, notifications, wallpaper, lock screen, idle behavior, screenshots, clipboard, and control center.
- [`sddm`](https://github.com/sddm/sddm) — display manager.
- [`fcitx5`](https://github.com/fcitx/fcitx5) + chewing — Chinese input.

### macOS extras

- [`aerospace`](https://github.com/nikitabobko/AeroSpace) — tiling WM.
- [`karabiner-elements`](https://karabiner-elements.pqrs.org) — keyboard remapper.
- [`raycast`](https://raycast.com) — launcher.
- Desktop wallpaper is deployed by chezmoi to `~/.config/wallpapers` and applied by `run_onchange_after_3-configure-macos-wallpaper.sh.tmpl`.

### CLI tooling

- File / dir: [`eza`](https://github.com/eza-community/eza), [`fd`](https://github.com/sharkdp/fd), [`ripgrep`](https://github.com/BurntSushi/ripgrep), [`bat`](https://github.com/sharkdp/bat), [`zoxide`](https://github.com/ajeetdsouza/zoxide), [`fzf`](https://github.com/junegunn/fzf).
- System info: [`btop`](https://github.com/aristocratos/btop), [`fastfetch`](https://github.com/fastfetch-cli/fastfetch).
- Git: [`lazygit`](https://github.com/jesseduffield/lazygit), [`tig`](https://github.com/jonas/tig), [`gh`](https://cli.github.com), [`glab`](https://gitlab.com/gitlab-org/cli), [`onefetch`](https://github.com/o2sh/onefetch).
- Build / dev: [`gnu-tar`](https://www.gnu.org/software/tar/), [`bear`](https://github.com/rizsotto/Bear), [`cmake`](https://cmake.org), [`mold`](https://github.com/rui314/mold), [`ninja`](https://ninja-build.org), [`llvm`](https://llvm.org), [`clang-format`](https://clang.llvm.org/docs/ClangFormat.html), [`cppcheck`](https://cppcheck.sourceforge.io), [`uv`](https://github.com/astral-sh/uv).
- Containers: [`podman`](https://podman.io).
- Docs: [`hugo`](https://gohugo.io), [`typst`](https://typst.app), [`tldr`](https://tldr.sh).
- OpenCode zh-TW linting: [`zhtw-mcp`](https://github.com/sysprog21/zhtw-mcp) is configured as a local MCP server at `~/.local/bin/zhtw-mcp`. Until upstream publishes releases, install it from source with `make install` so OpenCode can use the fixed binary path.
- OpenCode Loop: [`@bybrawe/opencode-loop@0.5.1`](https://github.com/ByBrawe/opencode-loop) is loaded through OpenCode's native npm plugin support, with `/loop*` command stubs managed under `~/.config/opencode/commands/`.
- OpenCode Claude Code plugin: [`@khalilgharbaoui/opencode-claude-code-plugin@0.6.2`](https://github.com/khalilgharbaoui/opencode-claude-code-plugin) is loaded through OpenCode's native npm plugin support; after changing the plugin path, run `chezmoi apply /home/collie/.config/opencode/opencode.json` and restart OpenCode.

### Fish plugins (managed by [`fisher`](https://github.com/jorgebucaran/fisher))

- `catppuccin/fish` — colour theme.
- `edc/bass` — run bash scripts in fish.
- `jorgebucaran/nvm.fish` — Node version manager.
- `patrickf1/fzf.fish` — fzf integrations.
- `pure-fish/pure` — minimal prompt.

### Tmux plugins (managed by [`TPM`](https://github.com/tmux-plugins/tpm))

- `catppuccin/tmux` — status-bar theme.
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
├── .chezmoidata/packages.yaml   # canonical package list (pacman + apt)
├── .chezmoiexternal.toml.tmpl   # auto-pulled theme files
├── .chezmoiscripts/             # run_once / run_onchange bootstrap
├── .chezmoitemplates/           # macOS install template (Brewfile pass-thru)
└── dot_config/                  # → ~/.config/...
```
