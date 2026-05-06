# Collie's Dotfiles

A comprehensive dotfiles configuration managed with [chezmoi](https://github.com/twpayne/chezmoi), supporting multiple platforms including macOS and Linux (Arch-based distros).

## 🚀 Quick Start

### Prerequisites
- [git](https://github.com/git/git)
- [chezmoi](https://github.com/twpayne/chezmoi)

### Installation
```bash
chezmoi init --apply collieiscute -v
```

## 📁 Configuration Overview

This dotfiles collection includes configurations for:

### 🛠️ Development Tools
- **[Neovim](https://github.com/neovim/neovim)** - Modern Vim-based editor with [LazyVim](https://github.com/LazyVim/LazyVim)
  ```
  ├── Core Plugins
  │   ├── [zbirenbaum/copilot.lua](https://github.com/zbirenbaum/copilot.lua)           # AI-powered code completion
  │   ├── [giuxtaposition/blink-cmp-copilot](https://github.com/giuxtaposition/blink-cmp-copilot) # Copilot integration for blink.cmp
  │   ├── [neovim/nvim-lspconfig](https://github.com/neovim/nvim-lspconfig)            # LSP configuration
  │   ├── [p00f/clangd_extensions.nvim](https://github.com/p00f/clangd_extensions.nvim)      # Enhanced clangd support
  │   ├── [nvim-treesitter/nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter)  # Syntax highlighting
  │   ├── [ibhagwan/fzf-lua](https://github.com/ibhagwan/fzf-lua)                 # Fuzzy finder
  │   ├── [sphamba/smear-cursor.nvim](https://github.com/sphamba/smear-cursor.nvim)        # Smooth cursor animation
  │   └── [folke/snacks.nvim](https://github.com/folke/snacks.nvim)                # Collection of useful utilities
  └── Features
      ├── AI completion with Copilot
      ├── Advanced C/C++ support with clangd
      ├── Fuzzy finding and navigation
      └── Modern syntax highlighting
  ```

- **[Tmux](https://github.com/tmux/tmux)** - Terminal multiplexer with [TPM](https://github.com/tmux-plugins/tpm)
  ```
  ├── Plugin Manager: [tmux-plugins/tpm](https://github.com/tmux-plugins/tpm)
  ├── Plugins
  │   ├── [catppuccin/tmux](https://github.com/catppuccin/tmux)               # Catppuccin theme (follows main)
  │   └── [tmux-plugins/tmux-sensible](https://github.com/tmux-plugins/tmux-sensible)      # Sensible defaults
  └── Features
      ├── Catppuccin Mocha theme
      ├── Mouse support
      └── Custom key bindings (C-a prefix)
  ```

- **[Zellij](https://zellij.dev/)** - Terminal workspace (modern alternative to tmux)
  ```
  ├── Theme: catppuccin-mocha (built-in, no plugin needed)
  └── Features
      ├── Built-in Catppuccin themes since v0.34.3
      └── KDL-based config, layout-driven sessions
  ```

- **[Fish Shell](https://fishshell.com/)** - Smart shell with [Fisher](https://github.com/jorgebucaran/fisher)
  ```
  ├── Plugin Manager: [jorgebucaran/fisher](https://github.com/jorgebucaran/fisher)
  ├── Plugins
  │   ├── [catppuccin/fish](https://github.com/catppuccin/fish)                  # Catppuccin theme
  │   ├── [edc/bass](https://github.com/edc/bass)                         # Bass shell integration
  │   ├── [jorgebucaran/nvm.fish](https://github.com/jorgebucaran/nvm.fish)           # Node version manager
  │   ├── [PatrickF1/fzf.fish](https://github.com/PatrickF1/fzf.fish)              # FZF integration
  │   └── [pure-fish/pure](https://github.com/pure-fish/pure)                   # Minimal prompt
  └── Features
      ├── Platform-specific configurations (macOS/Linux)
      ├── Git aliases and shortcuts
      ├── Enhanced navigation with [zoxide](https://github.com/ajeetdsouza/zoxide)
      └── Catppuccin theme support
  ```

### 🚀 Hyprland Ecosystem
- **[Hyprland](https://hyprland.org/)** - Dynamic tiling Wayland compositor
  ```
  ├── Core Components
  │   ├── hyprland                        # Main compositor
  │   ├── hypridle                        # Idle daemon
  │   ├── hyprlock                        # Screen locker
  │   ├── hyprpaper                       # Wallpaper utility
  │   └── hyprshot                        # Screenshot tool
  ├── Status & UI
  │   ├── [waybar](https://github.com/Alexays/Waybar)                          # Status bar
  │   ├── [swaync](https://github.com/ErikReider/SwayNotificationCenter)                          # Notification center
  │   └── [wofi](https://github.com/uncomfyhalomacro/wofi)                            # Application launcher
  ├── System Integration
  │   ├── [xdg-desktop-portal-hyprland](https://github.com/hyprwm/xdg-desktop-portal-hyprland)     # Desktop portal
  │   ├── [xorg-xwayland](https://gitlab.freedesktop.org/xorg/xserver)                   # X11 compatibility
  │   └── [wayland-protocols](https://gitlab.freedesktop.org/wayland/wayland-protocols)               # Wayland protocols
  ├── Audio & Media
  │   ├── [pipewire](https://pipewire.org/) + [pipewire-pulse](https://pipewire.org/)       # Audio system
  │   ├── [wireplumber](https://github.com/PipeWire/wireplumber)                     # Audio session manager
  │   └── [playerctl](https://github.com/altdesktop/playerctl)                       # Media control (for Waybar)
  └── Bluetooth & Connectivity
      ├── [blueman](https://github.com/blueman-project/blueman)                         # Bluetooth manager GUI
      ├── [bluez](http://www.bluez.org/) + bluez-utils             # Bluetooth stack
      └── [network-manager-applet](https://gitlab.gnome.org/GNOME/network-manager-applet)          # Network management
  ```

- **[Alacritty](https://github.com/alacritty/alacritty)** - GPU-accelerated terminal emulator
- **[Kitty](https://sw.kovidgoyal.net/kitty/)** - Feature-rich GPU terminal (used on macOS for AeroSpace single-window tab handling)
- **[WezTerm](https://wezfurlong.org/wezterm/)** - Cross-platform terminal emulator

## 🎨 Unified Theme & Integration

### Catppuccin Theme Ecosystem
All tools share the **[Catppuccin](https://catppuccin.com/)** color palette for visual consistency:
- **[Fish Shell](https://fishshell.com/)** - [Catppuccin Mocha](https://github.com/catppuccin/fish) theme with Pure prompt
- **[Tmux](https://github.com/tmux/tmux)** - [Catppuccin theme](https://github.com/catppuccin/tmux) (follows main) with custom status bar
- **[Neovim](https://github.com/neovim/neovim)** - LazyVim with [Catppuccin](https://github.com/catppuccin/nvim) integration
- **[Waybar](https://github.com/Alexays/Waybar)** - [Catppuccin Frappe](https://github.com/catppuccin/waybar) color scheme
- **[Alacritty](https://github.com/alacritty/alacritty)** - [Catppuccin Mocha](https://github.com/catppuccin/alacritty) (auto-refreshed weekly via chezmoi external)
- **[Kitty](https://sw.kovidgoyal.net/kitty/)** - [Catppuccin Macchiato](https://github.com/catppuccin/kitty) (auto-refreshed weekly via chezmoi external)
- **[WezTerm](https://wezfurlong.org/wezterm/)** - Catppuccin Mocha (built-in color_scheme)
- **[Zellij](https://zellij.dev/)** - Catppuccin Mocha (built-in theme since v0.34.3)
- **[SwayNC](https://github.com/ErikReider/SwayNotificationCenter)** - Custom [Catppuccin Frappe](https://github.com/catppuccin/swaync) styling

### Integrated Keybindings
Unified keybinding scheme across all applications:
```
🔧 System Control (Hyprland)
├── Super + T           → Terminal (Alacritty)
├── Super + E           → File Manager ([Nautilus](https://apps.gnome.org/Nautilus/))  
├── Super + C           → Close Window
├── Super + M           → Exit Hyprland
├── Super + V           → Toggle Floating
├── Super + N           → Toggle Notifications (SwayNC)
├── Super + Shift + L   → Lock Screen (Hyprlock)
└── Ctrl + Shift + P    → Screenshot Region (Hyprshot)

🎯 Navigation & Workspaces
├── Super + H/J/K/L     → Move Focus (Vim-style)
├── Super + 1-9         → Switch Workspace
├── Super + Shift + 1-9 → Move Window to Workspace
└── Super + S           → Special Workspace (Magic)

🎵 Media & System
├── XF86AudioRaise/Lower → Volume Control (PipeWire)
├── XF86AudioMute       → Mute Toggle
├── XF86MonBrightness   → Brightness Control
└── XF86AudioPlay/Pause → Media Control (Playerctl)
```

## 📋 System Requirements

### Primary Platforms (Actively Maintained)

#### 🍎 macOS
- [Homebrew](https://brew.sh/) package manager
- [Fish shell](https://fishshell.com/) (auto-configured)
- Chezmoi 2.54.0+

#### 🐧 Arch Linux
- [Pacman](https://archlinux.org/pacman/) package manager
- systemd for service management  
- Wayland compositor support
- AUR access via [Paru](https://github.com/Morganamilo/paru)

### CI/CD Testing Only
Other distributions (Ubuntu, CachyOS) are supported through automated testing but not actively maintained for daily use.

