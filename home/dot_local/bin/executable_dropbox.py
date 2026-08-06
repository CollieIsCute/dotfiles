#!/bin/sh
set -eu

/usr/bin/python3 -I -c 'import gpg; gpg.Context()'
exec env -u DISPLAY -u WAYLAND_DISPLAY /usr/bin/python3 -I "$HOME/.local/lib/dropbox/dropbox.py" "$@"
