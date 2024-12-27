FROM manjarolinux/base:latest

ENV USER=dev
ENV HOME=/home/$USER

RUN pacman -Syu --noconfirm \
    git \
    chezmoi \
    sudo \
    openssh \
    fish \
    && useradd -m -s /usr/bin/fish $USER \
    && echo "$USER ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

ENV CHEZMOI_VERBOSE=1

USER $USER
WORKDIR $HOME

ENTRYPOINT ["sh", "-c", "chezmoi init --apply https://github.com/CollieIsCute/old-dotfiles.git --branch feature/introduce_chezmoi --verbose && exec fish"]

