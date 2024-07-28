#!/bin/sh

###############
# Xrandr

# List devices
alias xrandr_ls="xrandr -q | awk '/connected/ {print \$1}'"
alias xrandr_connected="xrandr -q | awk '/ connected/{print \$1}'"
alias xrandr_disconnected="xrandr -q | awk '/disconnected/{print \$1}'"
alias xrandr_on="xrandr -q | awk '/ connected/{name=\$1} /*/{print name}'"
alias xrandr_off="xrandr -q | awk 'BEGIN{name=\"\"} / connected/{if (length(name)>0) {print name}; name=\$1} /*/{name=\"\"} END{if (length(name)>0) {print name}}'"
alias xrandr_cfg="xrandr -q | awk '/connected/{d=\$1}/*/{print d \"\t\" \$1}'"

# Screen resolution
xrandr_size() {
  if [ $# -eq 0 ]; then
    xrandr -q | awk '/*/{print $1}'
  else
    xrandr -s "$@"
  fi
}
alias xrandr_getres='xrandr_size;'
alias xrandr_getsize='xrandr_size;'
alias xrandr_setres='xrandr_size'
alias xrandr_setsize='xrandr_size'
#alias xrandr_auto='xrandr_size 0'
alias xrandr_refresh='xrandr_size 0'
alias xrandr_4096='xrandr_size 4096x2160'
alias xrandr_2560='xrandr_size 2560x1440'
alias xrandr_1920='xrandr_size 1920x1080'
alias xrandr_1600='xrandr_size 1600x1200'
alias xrandr_1360='xrandr_size 1360x768'
alias xrandr_1280='xrandr_size 1280x1024'
alias xrandr_1024='xrandr_size 1024x768'
alias xrandr_800='xrandr_size 800x600'
alias xrandr_640='xrandr_size 640x480'

# Enable/disable screen
xrandr_auto() {
  local SCREEN="${1:?No screen specified...}"
  shift
  xrandr --output "${SCREEN}" --auto "$@"
}
xrandr_enable() {
  local SCREEN="${1:?No screen specified...}"
  local MODE="${2:?No mode specified... ex: 1024x768}"
  shift 2
  xrandr --addmode "${SCREEN}" "${MODE}"
  xrandr --output "${SCREEN}" --mode "${MODE}" "$@"
}
xrandr_disable() {
  local SCREEN="${1:?No screen specified...}"
  shift
  xrandr --output "${SCREEN}" --off "$@"
}

# Set scale
xrandr_scale() {
  local SCREEN="${1:?No screen specified...}"
  local SCALE="${2:-1x1}"
  shift 2
  xrandr --output "${SCREEN}" --scale "$SCALE" "$@"
}

# Set position
xrandr_pos() {
  local SCREEN1="${1:?No screen specified...}"
  local POS="${2:?No position specified...}"
  local SCREEN2="${3:?No screen specified...}"
  shift 3
  xrandr --output "${SCREEN2}" --${POS}-of "${SCREEN1}" "$@"
}

# Run a command and restore xrandr config afterwards
xrandr_safe() {
  local RET
  local RES="$(xrandr --current | grep \* | cut -d' ' -f4)"
  "$@"; RET=$?
  ${RES:+xrandr -s "$RES"}
  return $RET
}

###############
# Backlight

# Set backlight
alias backlight_100='backlight 100'
alias backlight_150='backlight 150'
alias backlight_250='backlight 250'
alias backlight_350='backlight 350'
alias backlight_500='backlight 500'
alias backlight_1000='backlight 1000'
backlight_reset() {
	sudo sh -c "
		echo 1 > /sys/class/backlight/acpi_video0/brightness
		echo 1 > /sys/class/backlight/acpi_video1/brightness
"
}
backlight() {
	sudo sh -c "echo ${1:-500} > /sys/class/backlight/${2:-intel}_backlight/brightness"
}

###############
# Mesa prime generic solution (!=primusrun)
# https://docs.mesa3d.org/envvars.html#envvar-DRI_PRIME
primerun() {
  vblank_mode=0 DRI_PRIME=1 "$@"
}

###############
# VGA switcheroo (nouveau driver)
# https://01.org/linuxgraphics/gfx-docs/drm/gpu/vga-switcheroo.html
# https://unix.stackexchange.com/questions/568378/nvidia-optimus-with-nouveau-drivers
if grep -i switcheroo /boot/config-* >/dev/null && lsmod | grep nouveau >/dev/null; then
  vgaswitcheroo_status() {
    sudo cat /sys/kernel/debug/vgaswitcheroo/switch
  }
  vgaswitcheroo_on() {
    echo ON | sudo tee /sys/kernel/debug/vgaswitcheroo/switch
    echo DIS | sudo tee /sys/kernel/debug/vgaswitcheroo/switch
  }
  vgaswitcheroo_off() {
    echo IGD | sudo tee /sys/kernel/debug/vgaswitcheroo/switch
    echo OFF | sudo tee /sys/kernel/debug/vgaswitcheroo/switch
  }
fi

###############
# Bumblebee bbswitch
# Package: bbswitch-dkms
# https://github.com/Bumblebee-Project/bbswitch
if test -f /proc/acpi/bbswitch; then
  alias bb_status='cat /proc/acpi/bbswitch'
  alias bb_on='sudo sh -c "echo ON > /proc/acpi/bbswitch"'
  alias bb_off='sudo sh -c "echo OFF > /proc/acpi/bbswitch"'
fi

###############
# nvidia-prime solution (!=primusrun)
nvprimerun() {
  vblank_mode=0 __NV_PRIME_RENDER_OFFLOAD=1 __VK_LAYER_NV_optimus=NVIDIA_only __GLX_VENDOR_LIBRARY_NAME=nvidia "$@"
}

###############
# Bumblebee wrappers for optirun/primusrun
# Note 1: install bumblebee with primus backend instead of virtualGL
#         because primusrun perfs > optirun (virtualGL) perfs
# Note 2: do not mess with nvidia prime (!=primus)
#~ if command -v primusrun >/dev/null; then
  #~ optirun() { primusrun "$@"; }
  #~ primusrun() {
    #~ sudo sh -c '
      #~ USER="$1"; shift
      #~ CONF=/usr/lib/modprobe.d/blacklist-nvidia.conf
      #~ trap "if [ -f "${CONF}.tmp" ]; then mv -v \"${CONF}.tmp\" \"$CONF\"; fi; trap - INT TERM EXIT" INT TERM EXIT
      #~ if [ -f "$CONF" ]; then mv -v "$CONF" "${CONF}.tmp"; fi
      #~ #modprobe nvidia
      #~ #vblank_mode=0 command primusrun "$@"
      #~ #rmmod nvidia nvidia_modeset nvidia_drm
      #~ sudo -u "$USER" vblank_mode=0 primusrun "$@"
    #~ ' _ "$(whoami)" "$@"
  #~ }
#~ fi
