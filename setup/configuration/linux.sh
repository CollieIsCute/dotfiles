#!/usr/bin/bash
source ${DOTFILE_PATH}/setup/configuration/common.sh
cp -lR --remove-destination ${DOTFILE_PATH}/home/.[!.]* ~

# switch shell to fish
echo -e "${GREEN}Switching shell to fish...${NC}"
chsh -s $(which fish)