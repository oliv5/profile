#!/bin/sh
# Install instructions
#   sudo apt install weston waydroid
#   sudo waydroid init -f -s GAPPS # For installing Gapps
#   sudo waydroid init -f # No Gapps
# Note about clipboard
#   https://github.com/waydroid/waydroid/issues/309#issuecomment-1329881878
#   https://github.com/waydroid/waydroid/issues/1300
if true; then
    weston --socket=/run/user/$(id -u)/wayland-1 &
    WAYLAND_DISPLAY=wayland-1 waydroid show-full-ui &
else
    weston --socket=/run/user/$(id -u)/wayland-0 &
    waydroid show-full-ui &
fi
echo "Press enter to stop"
read _A
waydroid session stop
pkill weston
