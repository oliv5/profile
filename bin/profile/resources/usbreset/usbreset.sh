#!/bin/sh
DEVICE="${1:?No usb device name to look for in 'lsusb'...}"
lsusb | awk '/'"$DEVICE"'/ { print "/dev/bus/usb/" $2 "/" $4 }' | tr -d : | xargs -r -n1 sudo "$(command -v usbreset)"
