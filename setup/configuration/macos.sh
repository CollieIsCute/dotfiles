#!/bin/bash
DOTFILE_PATH="$(pwd -P)/.."
GREEN='\033[1;32m'
NC='\033[0m'

echo -e "${GREEN}Setting up configurations...${NC}"
echo -e "Copying following files to ~/:"
for f in ${DOTFILE_PATH}/home/.[!.g]*; do
	echo ${f}
done
# symbolic link all files except .gitignore, if dest file exists, overwrite it
rm -rf ~/.config/fish
rm -rf ~/.config/nvim
rm -rf ~/.config/omf
rm -f ~/.clang-format
rm -f ~/.tmux.conf
rm -f ~/.tmux.conf.local
rm -f ~/README.md
ln -Ffws ${DOTFILE_PATH}/home/.[!.]* ~/

# install packages
brew bundle install --file=install_package/Brewfile

# switch shell to fish
echo -e "${GREEN}Switching shell to fish...${NC}"
# if fish is not in /etc/shells, add it
if ! grep -q "$(which fish)" /etc/shells; then
	echo "Adding fish to /etc/shells..."
	echo "$(which fish)" | sudo tee -a /etc/shells
fi
chsh -s $(which fish)
echo -e "${GREEN}Please log out and log in again to make fish shell work${NC}"