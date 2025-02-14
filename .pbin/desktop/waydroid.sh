#!/bin/sh
# Install instructions
#   sudo apt install weston waydroid
#   sudo waydroid init -f -s GAPPS # For installing Gapps
#   sudo waydroid init -f # No Gapps
# Note about clipboard
#   https://github.com/waydroid/waydroid/issues/309#issuecomment-1329881878
#   https://github.com/waydroid/waydroid/issues/1300

WAYLAND_DISPLAY=/run/user/$(id -u)/wayland-waydroid-1

case "$1" in
    start | run)
        weston --socket="$WAYLAND_DISPLAY" &
        WAYLAND_DISPLAY="$(basename "$WAYLAND_DISPLAY")" waydroid show-full-ui &
        ;;

    stop | end)
        waydroid session stop
        pkill -f "weston --socket=$WAYLAND_DISPLAY"
        ;;

    poll)
        while pgrep waydroid >/dev/null; do
            sleep 10
        done
        ;;

    wait)
        echo "Press enter to stop"
        read __
        ;;
esac
unset WAYLAND_DISPLAY
