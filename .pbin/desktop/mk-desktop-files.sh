#!/bin/sh
NAME="${1:?No desktop file name specified...}"
EXEC="${2:?No execution command line specified...}"
ICON="$3"
TERMINAL="$4"
CATEGORIES="$5"
NOTIFY="$6"
NODISPLAY="$7"

FILE="$HOME/.local/share/applications/${NAME}.desktop"

cat <<EOF > "$FILE"
[Desktop Entry]
Name=$NAME
Exec=$EXEC
Type=Application
Terminal=${TERMINAL:-false}
${ICON:+Icon=$ICON}
${NOTIFY:+StartupNotify=$NOTIFY}
${NODISPLAY:+NoDisplay=$NODISPLAY}
${CATEGORIES:+Categories=$CATEGORIES}
EOF

ls -la "$FILE"
cat "$FILE"
