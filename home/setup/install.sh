#!/bin/bash
export DOTFILE_PATH="$(pwd -P)/.."
export GREEN='\033[1;32m'
export NC='\033[0m'
echo -e "${GREEN}Setting up...${NC}"
echo -e "${GREEN}May need root permission to install packages${NC}"

os_name=$(uname -s)
case $os_name in
Linux)
	if [[ ! -e /etc/os-release ]]; then
		echo "/etc/os-release file not exist, cannot determine Linux distro and break!"
		exit 1
	fi
	distro_name=$(grep -E '^ID=' /etc/os-release | cut -d= -f2 | tr -d '"')
	case $distro_name in
	arch | manjaro)
		echo "Using Arch setting..."
		sudo -E ./install_package/arch.sh
		source ./configuration/linux.sh
		;;
	ubuntu)
		echo "Using Ubuntu setting..."
		sudo -E ./install_package/ubuntu.sh
		source ./configuration/linux.sh
		;;
	*)
		echo "Using some Linux distro which isn't supported yet."
		exit 1
		;;
	esac
	;;
Darwin)
	echo "Using MacOS setting..."
	source ./install_package/macos.sh
	source ./configuration/macos.sh
	;;
*)
	echo "This setup hasn't been supported yet. Please set up the system manually."
	exit 1
	;;
esac

echo -e "${GREEN}All setup steps finished!${NC}"
