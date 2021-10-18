#!bash
# install ohmyzsh
sh -c "$(wget -O- https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
# add theme of zsh
cp ./agnosterzak.zsh-theme ~/.oh-my-zsh/themes/
# install autosuggesstions
git clone https://github.com/zsh-users/zsh-autosuggestions ~/.zsh/zsh-autosuggestions
# install you-should-use
git clone https://github.com/MichaelAquilina/zsh-you-should-use.git $ZSH_CUSTOM/plugins/you-should-use
# set .zshrc
ln -sf `pwd -P`/.zshrc ~/.zshrc
# set .tmux.conf
ln -sf `pwd -P`/.tmux.conf ~/.tmux.conf