# Collie's Dotfiles

A comprehensive dotfiles configuration managed with [chezmoi](https://github.com/twpayne/chezmoi), supporting multiple platforms including macOS and Linux (Manjaro).

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
  │   ├── zbirenbaum/copilot.lua           # AI-powered code completion
  │   ├── giuxtaposition/blink-cmp-copilot # Copilot integration for blink.cmp
  │   ├── neovim/nvim-lspconfig            # LSP configuration
  │   ├── p00f/clangd_extensions.nvim      # Enhanced clangd support
  │   ├── nvim-treesitter/nvim-treesitter  # Syntax highlighting
  │   ├── ibhagwan/fzf-lua                 # Fuzzy finder
  │   ├── sphamba/smear-cursor.nvim        # Smooth cursor animation
  │   └── folke/snacks.nvim                # Collection of useful utilities
  └── Features
      ├── AI completion with Copilot
      ├── Advanced C/C++ support with clangd
      ├── Fuzzy finding and navigation
      └── Modern syntax highlighting
  ```

- **[Tmux](https://github.com/tmux/tmux)** - Terminal multiplexer with [TPM](https://github.com/tmux-plugins/tpm)
  ```
  ├── Plugin Manager: tmux-plugins/tpm
  ├── Plugins
  │   ├── catppuccin/tmux#v2.1.3          # Catppuccin theme
  │   └── tmux-plugins/tmux-sensible      # Sensible defaults
  └── Features
      ├── Catppuccin Mocha theme
      ├── Mouse support
      └── Custom key bindings (C-a prefix)
  ```

- **[Fish Shell](https://fishshell.com/)** - Smart shell with [Fisher](https://github.com/jorgebucaran/fisher)
  ```
  ├── Plugin Manager: jorgebucaran/fisher
  ├── Plugins
  │   ├── catppuccin/fish                  # Catppuccin theme
  │   ├── edc/bass                         # Bass shell integration
  │   ├── jorgebucaran/nvm.fish           # Node version manager
  │   ├── PatrickF1/fzf.fish              # FZF integration
  │   └── pure-fish/pure                   # Minimal prompt
  └── Features
      ├── Platform-specific configurations (macOS/Linux)
      ├── Git aliases and shortcuts
      ├── Enhanced navigation with zoxide
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
  │   ├── waybar                          # Status bar
  │   ├── swaync                          # Notification center
  │   └── wofi                            # Application launcher
  ├── System Integration
  │   ├── xdg-desktop-portal-hyprland     # Desktop portal
  │   ├── xorg-xwayland                   # X11 compatibility
  │   └── wayland-protocols               # Wayland protocols
  └── Audio & Media
      ├── pipewire + pipewire-pulse       # Audio system
      ├── wireplumber                     # Audio session manager
      └── playerctl                       # Media control (for Waybar)
  ```

- **[Alacritty](https://github.com/alacritty/alacritty)** - GPU-accelerated terminal emulator
- **[WezTerm](https://wezfurlong.org/wezterm/)** - Cross-platform terminal emulator

### ⚙️ System Tools
- **[Karabiner Elements](https://karabiner-elements.pqrs.org/)** - Keyboard customizer for macOS
- **[Paru](https://github.com/Morganamilo/paru)** - AUR helper configuration

## 📦 Package Management

### Homebrew (macOS)
The `Brewfile` includes essential development tools:
- **Languages**: Python (pyenv), Node.js, LLVM, GCC
- **Development**: Git, Docker, CMake, Ninja, Poetry
- **Utilities**: ripgrep, bat, eza, zoxide, btop
- **Applications**: Brave Browser, VSCode, Raycast, Rectangle

### Package Categories
- **Build Tools**: cmake, ninja, bear, mold
- **Version Control**: git, tig
- **File Management**: eza, bat, ripgrep
- **Network**: curl, wget, openssh
- **Container**: docker, docker-compose, colima

## 🐧 Linux Support

### Manjaro Docker Testing
Includes a Dockerfile for testing the dotfiles in a Manjaro Linux environment:
```bash
docker build -f manjaro.dockerfile -t dotfiles-test .
docker run -it dotfiles-test
```

## 🔧 Configuration Features

### Fish Shell
- Platform-specific configurations (macOS/Linux)
- Git aliases and shortcuts
- Enhanced navigation commands
- Integration with zoxide and neovim
- Catppuccin theme support

### Neovim
- LazyVim-based configuration
- Custom keymaps and options
- Plugin management with lazy.nvim
- Language server support (clangd, copilot)

### Terminal Enhancement
- Custom color schemes (Catppuccin Frappe)
- Performance optimizations
- Cross-platform compatibility

## 📋 System Requirements

### macOS
- Homebrew package manager
- Fish shell (auto-configured)
- Chezmoi 2.54.0+

### Linux (Manjaro)
- Pacman package manager
- systemd for service management
- Wayland compositor support

## 🔄 Updates and Maintenance

The configuration supports easy updates through:
- `buu` command (brew update && upgrade && fisher update)
- Chezmoi template system for platform-specific configs
- Modular configuration structure

## 📄 License

Personal dotfiles configuration - use and modify as needed. 
