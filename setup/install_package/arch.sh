#!/bin/bash
GREEN='\033[1;32m'
NC='\033[0m'

# List of packages to be installed using Pacman
pacman_packages=(
	"bat"
	"base-devel"
	"brave-browser"
	"clang"
	"curl"
	"discord"
	"fish"
	"git"
	"htop"
	"ibus-chewing"
	"neofetch"
	"neovim"
	"openssh"
	"telegram-desktop"
	"the_silver_searcher"
	"tig"
	"tree"
	"tmux"
	"wget"
)

echo -e "${GREEN}Installing packages...${NC}"

# Update Pacman database and install packages
sudo pacman -Syu --noconfirm
sudo pacman -S "${pacman_packages[@]}" --noconfirm

echo -e "${GREEN}All packages installed!${NC}"
