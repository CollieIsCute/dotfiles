#!/bin/bash
# setup pacman parallel downloads
sudo sed -i 's/#ParallelDownloads = 5/ParallelDownloads = 5/g' /etc/pacman.conf

# List of packages to be installed using Pacman
pacman_packages=(
	"bat"
	"base-devel"
	"brave-browser"
	"clang"
	"curl"
	"discord"
	"docker"
	"docker-compose"
	"fish"
	"git"
	"htop"
	"ibus-chewing"
	"neofetch"
	"neovim"
	"net-tools"
	"openssh"
	"teams"
	"telegram-desktop"
	"the_silver_searcher"
	"tig"
	"tldr"
	"tree"
	"tmux"
	"wget"
)

echo -e "${GREEN}Installing packages...${NC}"

# Update Pacman database and install packages
sudo pacman -Syu --noconfirm
sudo pacman -S "${pacman_packages[@]}" --noconfirm

# Install paru
(cd /tmp && git clone https://aur.archlinux.org/paru.git && cd paru && makepkg -si --noconfirm)

echo -e "${GREEN}All packages installed!${NC}"
. ${DOTFILE_PATH}/setup/install_package/common.sh