FROM manjarolinux/base:latest

ENV USER=dev
ENV HOME=/home/$USER

ENV CHEZMOI_VERBOSE=1

RUN pacman -Syu --noconfirm sudo && \
    useradd -m -s /usr/bin/fish $USER && \
    echo "$USER ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

USER $USER
WORKDIR $HOME

ENTRYPOINT ["sh", "-c", "sudo pacman -Syu --noconfirm chezmoi && chezmoi init --apply collieiscute -v && exec /bin/bash"]

