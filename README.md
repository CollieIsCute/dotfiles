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
- **[Neovim](https://github.com/neovim/neovim)** - Modern Vim-based editor with [LazyVim](https://github.com/LazyVim/LazyVim) configuration
- **[Tmux](https://github.com/tmux/tmux)** - Terminal multiplexer with [oh my tmux](https://github.com/gpakosz/.tmux)
- **[Fish Shell](https://fishshell.com/)** - Smart command line shell with custom aliases and functions
- **[GDB](https://www.gnu.org/software/gdb/)** - GNU Debugger configuration

### 🎨 Window Management & UI
- **[Hyprland](https://hyprland.org/)** - Dynamic tiling Wayland compositor
- **[Waybar](https://github.com/Alexays/Waybar)** - Highly customizable status bar
- **[Alacritty](https://github.com/alacritty/alacritty)** - GPU-accelerated terminal emulator
- **[WezTerm](https://wezfurlong.org/wezterm/)** - Cross-platform terminal emulator

### ⚙️ System Tools
- **[Karabiner Elements](https://karabiner-elements.pqrs.org/)** - Keyboard customizer for macOS
- **[SwayNC](https://github.com/ErikReider/SwayNotificationCenter)** - Notification daemon
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
