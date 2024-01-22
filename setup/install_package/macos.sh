#!/bin/zsh

# install homebrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
# install packages
brew bundle install --file=install_package/Brewfile