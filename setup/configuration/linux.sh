#!/usr/bin/bash
cp -lR --remove-destination ${DOTFILE_PATH}/home/.[!.]* ~
source ${DOTFILE_PATH}/setup/configuration/common.sh
# switch shell to fish
echo -e "${GREEN}Switching shell to fish...${NC}"
chsh -s $(which fish)