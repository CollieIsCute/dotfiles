#!bash
echo start setup.sh

echo "installing git and base-devel..."
# install git
sudo pacman -S --needed base-devel
sudo pacman -S git

echo "install paru"
# install paru
git clone https://aur.archlinux.org/paru.git ~/paru
cd ~/paru
makepkg -si

echo "install zsh setup zsh environment"
# setup zsh shell
paru zsh
cd zsh_settings
./setup.sh

echo "install others"
# install others
sudo pacman -S tmux make ibus ibus-chewing pulseaudio pamixer vim blueman

echo other settings
# tmux setup and audio setting
ln -s ~/syncfolder/Setup-For-Linux/.tmux.conf ~/.tmux.conf
pulseaudio --start
systemctl enable bluetooth.service

# setup default shell
echo change shell to tmux
chsh -s $(which tmux)
paru
