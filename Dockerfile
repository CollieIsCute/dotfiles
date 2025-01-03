FROM manjarolinux/base:latest

ENV USER=dev
ENV HOME=/home/$USER

ENV CHEZMOI_VERBOSE=1

RUN pacman -Syu --noconfirm sudo chezmoi && \
    useradd -m -s /usr/bin/fish $USER && \
    echo "$USER ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

USER $USER
WORKDIR $HOME

ENTRYPOINT ["sh", "-c", "chezmoi init --apply https://github.com/CollieIsCute/old-dotfiles.git --branch feature/introduce_chezmoi --verbose && exec /bin/bash"]

