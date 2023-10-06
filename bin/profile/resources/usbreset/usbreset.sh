#!/bin/sh
DEVICE="${1:?No usb device name to look for in 'lsusb'...}"
USBRESET="$(command -v usbreset || ls ./usbreset 2>/dev/null)"
lsusb | awk '/'"$DEVICE"'/ { print "/dev/bus/usb/" $2 "/" $4 }' | tr -d : | xargs -r -n1 sudo "${USBRESET:?usbreset was not found...}"
