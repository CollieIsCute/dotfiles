# Use Manjaro as the base image
FROM manjarolinux/base:latest

# Set environment variables
ENV USER=dev
ENV HOME=/home/$USER

# Install necessary packages
RUN pacman -Syu --noconfirm \
    git \
    chezmoi \
    sudo \
    openssh \
    && useradd -m -s /bin/bash $USER \
    && echo "$USER ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

ENV CHEZMOI_VERBOSE=1

USER $USER
WORKDIR $HOME

RUN chezmoi init --branch feature/introduce_chezmoi --apply https://github.com/CollieIsCute/old-dotfiles.git --verbose

CMD ["/bin/bash"]

