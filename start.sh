#!/bin/sh

SHELL_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell"
LINK="$CONFIG_DIR/mcshell"

# Symlink source into quickshell config dir if not already there
if [ ! -e "$LINK" ]; then
    mkdir -p "$CONFIG_DIR"
    ln -s "$SHELL_DIR" "$LINK"
    echo "Linked $SHELL_DIR -> $LINK"
elif [ "$(readlink -f "$LINK")" != "$SHELL_DIR" ]; then
    rm -f "$LINK"
    ln -s "$SHELL_DIR" "$LINK"
    echo "Updated link $LINK -> $SHELL_DIR"
fi

export QT_LOGGING_RULES="qt.qpa.services.warning=false"
exec mcs-qs -c mcshell "$@"
