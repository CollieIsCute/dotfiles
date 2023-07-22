#!/usr/bin/bash
DOTFILE_PATH="`pwd -P`/.."
GREEN='\033[1;32m'
NC='\033[0m'

echo -e "${GREEN}Setting up configurations...${NC}"
echo -e "Copying following files to ~/:"
for f in ${DOTFILE_PATH}/home/.[!.g]*
do
	echo ${f}
done
cp -lR --remove-destination ${DOTFILE_PATH}/home/.[!.g]* ~
#install ohmyzsh
sh -c "$(yes | curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
echo -e "${GREEN}Configurating zsh and tmux, and this may need user password...${NC}"
echo -e "${GREEN}Installing zsh plugins...${NC}"
zsh -c 'git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions'
zsh -c 'git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting'
zsh -c 'git clone https://github.com/MichaelAquilina/zsh-you-should-use.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/you-should-use'

