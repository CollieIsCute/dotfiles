#!/bin/zsh

# install homebrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
eval "$(/opt/homebrew/bin/brew shellenv)"
brew update --force --quiet
chmod -R go-w "$(brew --prefix)/share/zsh"
# install packages
brew bundle install --file=install_package/Brewfile

# add brew path to fish
(fish -C "eval (/opt/homebrew/bin/brew shellenv) && exit")

# check & install oh-my-fish
if [ -z "$OMF_PATH" ]; then
<<<<<<< Updated upstream
    echo "Installing oh-my-fish..."

    # Install oh-my-fish and use EOF to force quit fish shell
    curl https://raw.githubusercontent.com/oh-my-fish/oh-my-fish/master/bin/install > install
    fish install --path=~/.local/share/omf --config=~/.config/omf
    rm -rf install
=======
    curl https://raw.githubusercontent.com/oh-my-fish/oh-my-fish/master/bin/install | fish
>>>>>>> Stashed changes
fi
. ${DOTFILE_PATH}/setup/install_package/common.sh