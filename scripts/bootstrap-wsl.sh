#!/usr/bin/env bash
set -euo pipefail

repo=${1:?Pass the mounted dotfiles checkout}
# Do not let Windows PATH entries select Windows package managers or executables.
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
source /etc/os-release

if (( EUID == 0 )); then
    linux_user=${2:?Pass the Linux username for root setup}
    if [[ ! $linux_user =~ ^[a-z_][a-z0-9_-]{0,31}$ || $linux_user == root ]]; then
        echo "Pass a valid non-root Linux username." >&2
        exit 1
    fi
    if [[ ${CHEZMOI_WSL_PASSWORD:-} == *$'\n'* || ${CHEZMOI_WSL_PASSWORD:-} == *$'\r'* ]]; then
        echo "The bootstrap password must not contain line breaks." >&2
        exit 1
    fi

    case "$ID" in
        arch)
            # Reuse the image's first-login setup, skipped by --no-launch.
            [[ -s /etc/pacman.d/gnupg/pubring.gpg ]] || /usr/lib/wsl/first-setup.sh
            pacman -Syu --needed --noconfirm sudo
            ;;
        ubuntu)
            if ! command -v sudo >/dev/null; then
                apt-get update
                apt-get install -y sudo
            fi
            ;;
        *) echo "Unsupported WSL distro: $ID" >&2; exit 1 ;;
    esac

    if id "$linux_user" >/dev/null 2>&1; then
        # Do not reset an existing account's password or repurpose a system account.
        [[ $(id -u "$linux_user") -ge 1000 ]] || { echo "Refusing a system account." >&2; exit 1; }
    else
        useradd -m -s /bin/bash "$linux_user"
        if [[ -n ${CHEZMOI_WSL_PASSWORD:-} ]]; then
            printf '%s:%s\n' "$linux_user" "$CHEZMOI_WSL_PASSWORD" | chpasswd
        else
            passwd "$linux_user"
        fi
    fi

    sudoers_rule=$(mktemp)
    trap 'rm -f -- "$sudoers_rule"' EXIT
    printf '%s ALL=(ALL:ALL) ALL\n' "$linux_user" > "$sudoers_rule"
    visudo -cf "$sudoers_rule"
    install -m 0440 "$sudoers_rule" "/etc/sudoers.d/90-chezmoi-wsl-$linux_user"
    # PowerShell selects this user before invoking the apply stage below.
    exit 0
fi

export PATH="$HOME/.local/bin:$PATH"
# Unattended installs can supply a password without changing sudo policy.
if [[ -n ${CHEZMOI_WSL_PASSWORD:-} ]]; then
    # sudo requires DISPLAY to be defined for automatic askpass, even without a GUI.
    export DISPLAY=${DISPLAY-}
    SUDO_ASKPASS=$(mktemp)
    export SUDO_ASKPASS
    trap 'rm -f -- "$SUDO_ASKPASS"' EXIT
    printf '%s\n' '#!/bin/sh' 'printf "%s\n" "$CHEZMOI_WSL_PASSWORD"' > "$SUDO_ASKPASS"
    chmod 0700 "$SUDO_ASKPASS"
fi
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
chezmoi --source "$repo" apply
