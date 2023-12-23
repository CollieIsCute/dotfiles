#!/usr/bin/bash
DOTFILE_PATH="$(pwd -P)/.."
GREEN='\033[1;32m'
NC='\033[0m'

echo -e "${GREEN}Setting up configurations...${NC}"
echo -e "Copying following files to ~/:"
for f in ${DOTFILE_PATH}/home/.[!.g]*; do
	echo ${f}
done
cp -lR --remove-destination ${DOTFILE_PATH}/home/.[!.]* ~
