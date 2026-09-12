#!/usr/bin/env bash
set -euo pipefail

repo=${1:?Pass the mounted dotfiles checkout}
if [[ $(id -u) == 0 ]]; then
    echo "Choose a non-root default WSL user before running chezmoi." >&2
    exit 1
fi

# Do not let Windows PATH entries select Windows package managers or executables.
export PATH="$HOME/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
source /etc/os-release
case "$ID" in
    ubuntu)
        if ! command -v curl >/dev/null || ! command -v git >/dev/null; then
            sudo apt-get -o Acquire::Retries=3 update
            sudo apt-get -o Acquire::Retries=3 install -y ca-certificates curl git
        fi
        ;;
    arch)
        sudo pacman -Syu --needed --noconfirm curl git
        ;;
    *) echo "Unsupported WSL distro: $ID (use Ubuntu or Arch)." >&2; exit 1 ;;
esac

if ! command -v chezmoi >/dev/null; then
    curl -fsSL https://get.chezmoi.io | sh -s -- -b "$HOME/.local/bin"
fi

# Share only the checkout. Linux HOME, caches and chezmoi state stay in WSL.
exec chezmoi --source "$repo" apply --verbose
