#!/usr/bin/fish

GREEN='\033[1;32m'
NC='\033[0m'
echo -e "${GREEN}Setting up...${NC}"
echo -e "${GREEN}May need root permission to install packages${NC}"

set os_name (uname -s)
switch $os_name
    case Linux
        if ! test -e /etc/os-release
            echo "/etc/os-release file not exist, cannot determine linux distro and break!"
            return 1
        end
        set distro_name (grep -E '^ID=' /etc/os-release | cut -d= -f2 | tr -d '"')
        switch $distro_name
            case arch manjaro
                echo "Using Arch setting..."
            case ubuntu
                echo "Using Ubuntu setting..."
                sudo ./install_package/ubuntu.sh
                ./configuration/ubuntu.sh
            case '*'
                echo "Using some linux distro which isn't support yet."
                return 1
        end
    case '*'
        echo "This setup havn't support yet. Please setup system manually."
        return 1
end

echo -e "${GREEN}All setup steps finished!${NC}"
