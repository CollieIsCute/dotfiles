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
    fish \
    && useradd -m -s /usr/bin/fish $USER \
    && echo "$USER ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

ENV CHEZMOI_VERBOSE=1

# Switch to the non-root user
USER $USER
WORKDIR $HOME

# Set the entrypoint to chezmoi init
ENTRYPOINT ["sh", "-c", "chezmoi init --apply https://github.com/CollieIsCute/old-dotfiles.git --branch feature/introduce_chezmoi --verbose && exec fish"]

