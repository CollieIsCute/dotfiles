#!/usr/bin/bash
GREEN='\033[1;32m'
NC='\033[0m'
echo -e "${GREEN}Setting up Ubuntu...${NC}"
echo -e "${GREEN}Need root permission to install packages${NC}"
sudo ./install_package/ubuntu.sh
./configuration/ubuntu.sh
echo -e "${GREEN}All setup steps finished!${NC}"
