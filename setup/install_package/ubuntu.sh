#!/usr/bin/bash
GREEN='\033[1;32m'
NC='\033[0m'

apt_packages=(
	"bat"
	"build-essential"
	"clang-format"
	"curl"
	"fish"
	"git"
	"htop"
	"ibus-chewing"
	"neofetch"
	"silversearcher-ag"
	"ssh"
	"tig"
	"tree"
	"tmux"
	"wget"
	"zsh"
)
snap_packages=(
	"discord"
	"nvim --classic"
	"telegram-desktop"
	"marksman"
)

echo -e "${GREEN}Installing packages...${NC}"
apt update && apt upgrade -y
apt install "${apt_packages[@]}" -y

# install brave
curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg arch=amd64] https://brave-browser-apt-release.s3.brave.com/ stable main" | tee /etc/apt/sources.list.d/brave-browser-release.list
apt update && apt install brave-browser

apt autoremove
for snap_pkg in "${snap_packages[@]}"; do
	snap install ${snap_pkg}
done
