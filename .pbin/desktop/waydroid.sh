#!/bin/sh
# Install instructions
#   sudo apt install weston waydroid
#   sudo waydroid init -f -s GAPPS # For installing Gapps
#   sudo waydroid init -f # No Gapps
# Note about clipboard
#   https://github.com/waydroid/waydroid/issues/309#issuecomment-1329881878
#   https://github.com/waydroid/waydroid/issues/1300
set +e
unset WAYLAND_DISPLAY WAYLAND_DISPLAY_NAME
WAYLAND_DISPLAY_NAME=wayland-waydroid-1
WIDTH=480 #600
HEIGHT=800 #1000

case "$1" in
    weston)
        weston --socket="/run/user/$(id -u)/$WAYLAND_DISPLAY_NAME" --width=$WIDTH --height=$HEIGHT & # weston tries to use existing $WAYLAND_DISPLAY if it is set, else it creates new --socket
        ;;

    run)
        WAYLAND_DISPLAY="$WAYLAND_DISPLAY_NAME" waydroid session start &
        sleep 1
        WAYLAND_DISPLAY="$WAYLAND_DISPLAY_NAME" waydroid show-full-ui &
        ;;

    start | run)
       "$0" weston
        sleep 1
       "$0" run
        ;;

    stop | end)
        waydroid session stop
        pkill -f "weston --socket=.*/$WAYLAND_DISPLAY_NAME"
        ;;

    restart)
        "$0" stop
        "$0" start
        ;;

    kill)
        waydroid session stop
        sudo waydroid container stop
        sudo pkill -f "/usr/bin/waydroid -w container start"
        pkill -f "weston --socket=.*/$WAYLAND_DISPLAY_NAME"
        ;;

    poll)
        while pgrep -f "weston --socket=.*/$WAYLAND_DISPLAY_NAME" >/dev/null; do
            sleep 5
        done
        ;;

    wait)
        echo "Press enter to stop"
        read __
        ;;

    # https://github.com/waydroid/waydroid/issues/584
    rotate-on)
        sudo waydroid shell wm set-user-rotation free
        ;;

    rotate-portrait)
        sudo waydroid shell wm set-user-rotation lock 0
        ;;

    rotate-landscape)
        sudo waydroid shell wm set-user-rotation lock 1
        ;;

    rotate-off)
        sudo waydroid shell wm set-user-rotation lock
        ;;

    # https://docs.waydro.id/usage/waydroid-prop-options
    wifi)
        shift
        sudo waydroid prop set persist.waydroid.fake_wifi "${@:-*}"
        ;;

    "")
        echo >&2 "export WAYLAND_DISPLAY=$WAYLAND_DISPLAY_NAME"
        ps -def | grep 'weston\|waydroid'
        ;;

    *) echo >&2 "Unknown command '$1'";;

esac
unset WAYLAND_DISPLAY WAYLAND_DISPLAY_NAME
