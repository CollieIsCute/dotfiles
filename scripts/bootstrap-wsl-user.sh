#!/usr/bin/env bash
set -euo pipefail

linux_user=${1:?Pass the Linux username}
if [[ $(id -u) != 0 || ! $linux_user =~ ^[a-z_][a-z0-9_-]{0,31}$ || $linux_user == root ]]; then
    echo "Run as root with a valid non-root Linux username." >&2
    exit 1
fi
if [[ ${CHEZMOI_WSL_PASSWORD:-} == *$'\n'* || ${CHEZMOI_WSL_PASSWORD:-} == *$'\r'* ]]; then
    echo "The bootstrap password must not contain line breaks." >&2
    exit 1
fi

export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
source /etc/os-release
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
