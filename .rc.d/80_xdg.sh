#!/bin/sh
xdg_autostart_visibility() {
    local PRGM="${1:?No program specified...}"
    local NO_DISPLAY="${2:-false}"
    local DESKTOP="$HOME/.local/share/applications/$PRGM.desktop"
    if [ -n "$3" ]; then
        DESKTOP="/etc/xdg/autostart/$PRGM.desktop"
    fi
    sudo sed -i "s/^NoDisplay=.*/NoDisplay=$NO_DISPLAY/" "$DESKTOP"
}

xdg_autostart_show_all() {
    local DESKTOP="$HOME/.local/share/applications"
    if [ -n "$1" ]; then
        DESKTOP="/etc/xdg/autostart"
    fi
    sudo sed -i 's/NoDisplay=true/NoDisplay=false/g' "$DESKTOP"/*.desktop
}

xdg_mkshortcut() {
    local EXEC="${1:?No command defined...}"
    local NAME="${2:?No desktop file name specified...}"
    local ICON="$3"
    local TERMINAL="${4:-false}"
    local NODISPLAY="${5:-false}"
    local DESKTOP="$HOME/.local/share/applications/${NAME}.desktop"
    local SUDO=""
    if [ -n "$6" ]; then
        DESKTOP="/etc/xdg/autostart/${NAME}.desktop"
        SUDO=sudo
    fi
    $SUDO cat >"$DESKTOP" <<EOF
[Desktop Entry]
Encoding=UTF-8
Version=1.0
Type=Application
Terminal=$TERMINAL
NoDisplay=$NODISPLAY
Name=$NAME
Exec=$EXEC
${ICON:+Icon=$ICON}
EOF
    $SUDO sed -i '/^$/d' "$DESKTOP"
}

xdg_mkshortcut_cmd() {
    local EXEC="${1:?No command defined...}"
    shift
    xdg_mkshortcut "/bin/sh -c '$EXEC'" "$@"
}

xdg_rmshortcut() {
    local NAME="${1:?No desktop file name specified...}"
    local DESKTOP="$HOME/.local/share/applications/${NAME}.desktop"
    rm "$DESKTOP"
}

xdg_extract_appimage_icon() {
    local EXEC="${1:?No command defined...}"
    "$EXEC" --appimage-extract
    rsync -av squashfs-root/usr/share/icons/hicolor/ "$HOME/.local/share/icons/hicolor/"
    rm -r squashfs-root
}

xdg_set_appimage_icon() {
    local EXEC="${1:?No command defined...}"
    local NAME="${2:?No desktop file name specified...}"
    local DESKTOP="$HOME/.local/share/applications/${NAME}.desktop"
    local ICON="$HOME/.local/share/icons/hicolor/"
    xdg_extract_appimage_icon "$EXEC"
    ICON="$(find "$ICON" -iname "${NAME}.*" | sort | head -n1)"
    grep -iF "Icon" "$DESKTOP" >/dev/null || echo "Icon=" >> "$DESKTOP"
    test -r "$ICON" && sed -i "s;^Icon=.*;Icon=$ICON;" "$DESKTOP"
    sed -i '/^$/d' "$DESKTOP"
}
