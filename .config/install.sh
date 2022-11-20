#!/bin/sh
#

# insrall brew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# install neovim npm
brew install neovim
brew install npm

# install packer.neovim
git clone --depth 1 https://github.com/wbthomason/packer.nvim && ~/.local/share/nvim/site/pack/packer/start/packer.nvim

# apply packer on nvim
nvim --headless -c 'autocmd User PackerComplete quitall' -c 'PackerSync'


