#!/bin/bash
source ./common.sh
# symbolic link all files except .gitignore, if dest file exists, overwrite it
rm -rf ~/.config/fish
rm -rf ~/.config/nvim
rm -rf ~/.config/omf
rm -f ~/.clang-format
rm -f ~/.tmux.conf
rm -f ~/.tmux.conf.local

cd $(pwd -P)/..
echo -e "DOTFILE_PATH: $(pwd -P)"
echo -e "Copying following files to ~/:"
for f in (pwd -P)/home/.*
    echo $f
    cp -R $f ~/
end

# if fish is not in /etc/shells, add it
if ! grep -q "fish" /etc/shells; then
	echo "Adding fish to /etc/shells..."
	echo "/opt/homebrew/bin/fish" | sudo tee -a /etc/shells
end
# if $SHELL is not fish, then change default shell to fish
if test "$SHELL" != "/opt/homebrew/bin/fish"
    echo "Changing default shell to fish..."
    chsh -s /opt/homebrew/bin/fish
end
echo -e "$GREEN""Please log out and log in again to make fish shell work""$NC"