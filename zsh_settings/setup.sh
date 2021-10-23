#!bash
# install ohmyzsh
sh -c "$(wget -O- https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
# add theme of zsh
cp ./agnosterzak.zsh-theme $ZSH_COSTUM/themes/
# install autosuggestions
git clone https://github.com/zsh-users/zsh-autosuggestions $ZSH_CUSTOM/plugins/autosuggestions
# install you-should-use
git clone https://github.com/MichaelAquilina/zsh-you-should-use.git $ZSH_CUSTOM/plugins/you-should-use
# install zsh-syntax-highlighting
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git $ZSH_CUSTOM/plugins/zsh-syntax-highlighting
# set .zshrc
ln -sf `pwd -P`/.zshrc ~/.zshrc
# set .tmux.conf
ln -sf `pwd -P`/.tmux.conf ~/.tmux.conf
