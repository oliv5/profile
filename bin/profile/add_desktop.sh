#!/bin/sh
set -e
NAME="${1:?No filename defined...}"
EXEC="${2:?No command line defined...}"
cat > "$HOME/.local/share/applications/$1" <<EOF
[Desktop Entry]
Encoding=UTF-8
Version=1.0
Type=Application
Name=$NAME
Exec=$EXEC
StartupNotify=false
EOF
