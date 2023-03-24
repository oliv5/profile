#!/bin/sh
set -e
NAME="${1:?No app name defined...}"
EXEC="${2:?No command line defined...}"
EXEC="$(readlink -f "$EXEC")"
DESKTOP="$HOME/.local/share/applications/${NAME%%.desktop}.desktop"
cat > "$DESKTOP" <<EOF
[Desktop Entry]
Encoding=UTF-8
Version=1.0
Type=Application
Name=$NAME
Exec=$EXEC
StartupNotify=false
EOF
ls -l "$DESKTOP"
cat "$DESKTOP"
