#!/bin/sh
xdg_autostart_visibility() {
    local PRGM="${1:?No program specified...}"
    local NO_DISPLAY="${2:-false}"
    sudo sed -i "s/^NoDisplay=.*/NoDisplay=$NO_DISPLAY/" "/etc/xdg/autostart/$PRGM.desktop"
}

xdg_autostart_show_all() {
    sudo sed -i 's/NoDisplay=true/NoDisplay=false/g' /etc/xdg/autostart/*.desktop
}
