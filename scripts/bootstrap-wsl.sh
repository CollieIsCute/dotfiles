#!/usr/bin/env bash
set -euo pipefail
export PATH="$HOME/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" DISPLAY=${DISPLAY-} SUDO_ASKPASS
((EUID != 0)) || {
  echo "Run as a non-root user." >&2
  exit 1
}
SUDO_ASKPASS=$(mktemp)
trap 'rm -f -- "$SUDO_ASKPASS"' EXIT
printf '%s\n' '#!/bin/sh' 'printf "%s\n" "$CHEZMOI_WSL_PASSWORD"' >"$SUDO_ASKPASS"
chmod 0700 "$SUDO_ASKPASS"
command -v chezmoi >/dev/null || sudo pacman -Syu --needed --noconfirm chezmoi
chezmoi --source "${1:?Pass the mounted dotfiles checkout}" apply
