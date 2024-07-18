echo -e "${GREEN}Setting up configurations...${NC}"
echo -e "Copying following files to ~/:"
for f in ${DOTFILE_PATH}/home/.[!.g]*; do
	echo ${f}
done

# install LazyVim
# required
mv ~/.config/nvim{,.bak}
mv ~/.local/share/nvim{,.bak}
mv ~/.local/state/nvim{,.bak}
mv ~/.cache/nvim{,.bak}
git clone https://github.com/LazyVim/starter ~/.config/nvim
rm -rf ~/.config/nvim/.git
cp -lR --remove-destination ${DOTFILE_PATH}/nvim/lua/* ~/.config/nvim/lua/