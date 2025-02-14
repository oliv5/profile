#!/bin/sh
# https://askubuntu.com/questions/1313445/how-do-i-install-vnc-on-a-headless-ubuntu-20-10
export DISPLAY="${1:-:1}"
RESOLUTION="${2:-2560x1440x24}"
SCREEN="${3:-0}"
VNC_PORT="${4:-5900}"
PASSWORD_FILE="${5:-$HOME/.vnc/passwd}"

if ! command -v Xvfb >/dev/null; then
    echo >&2 "Please install Xvfb: sudo apt update && sudo apt install xvfb"
    exit 1
fi

if ! command -v x11vnc >/dev/null; then
    echo >&2 "Please install x11vnc: sudo apt update && sudo apt install x11vnc"
    exit 1
fi

killall Xvfb x11vnc
Xvfb "$DISPLAY" -screen "$SCREEN" "$RESOLUTION" &
sleep 2

if pidof gdm3 >/dev/null; then
    gnome-shell --replace &
elif pidof xfce4-session; then
    xfce4-session &
fi

sleep 2
x11vnc -display "$DISPLAY" -forever -loop -noxdamage -repeat -rfbauth "$PASSWORD_FILE" -rfbport "$VNC_PORT" -shared
