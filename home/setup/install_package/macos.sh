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

