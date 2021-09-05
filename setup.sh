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

echo "install zsh and oh-my-zsh"
# setup zsh shell
sudo pacman -S zsh
git clone https://github.com/ohmyzsh/ohmyzsh.git ~/.oh-my-zsh
rm ~/.zshrc
ln -s ~/syncfolder/Setup-For-Linux/.zshrc ~/.zshrc
ln ~/syncfolder/Setup-For-Linux/agnosterzak.zsh-theme ~/.oh-my-zsh/themes/agnosterzak.zsh-theme  

echo "install others"
# install others
sudo pacman -S tmux make ibus ibus-chewing pulseaudio pamixer vim

echo other settings
# tmux setup and audio setting
ln -s ~/syncfolder/Setup-For-Linux/.tmux.conf ~/.tmux.conf
pulseaudio --start

# setup default shell
echo change shell to tmux
chsh -s $(which tmux)
paru