#!/bin/sh

################################
# Event tester
alias event_list='xev'
alias event_showkey='showkey -s'

################################
# Get XWindow ID
xwmid() {
  xwininfo | awk '/xwininfo: Window id:/ {print $4}'
}
# Get XWindow PID
xwmpid() {
  xprop -id "${1:-$(xwmid)}" | awk '/WM_PID/ {print $3}'
}
# My xkill
command -v xkill >/dev/null ||
xkill() {
  xwmid | xargs -r xdotool windowkill
}
# Close Xwindow
xclose() {
  xwmid | xargs -r xdotool windowclose
}

################################
# List displays
# https://unix.stackexchange.com/questions/17255/is-there-a-command-to-list-all-open-displays-on-a-machine
lsdisplay() {
  # Local display
  (cd /tmp/.X11-unix && for x in X*; do echo ":${x#X}"; done)
  # Remote displays (open TCP ports above 6000)
  command -v netstat >/dev/null &&
    netstat -lnt | awk '
    sub(/.*:/,"",$4) && $4 >= 6000 && $4 < 6100 {
      print ($1 == "tcp6" ? "ip6-localhost:" : "localhost:") ($4 - 6000)
    }'
  # Show which program has port 60xx opened
  lsof -i -n | awk '$9 ~ /:60[0-9][0-9]$/ {print}'
}

################################
show_windowing_system() {
  loginctl show-session $(awk '/tty/ {print $1}' <(loginctl)) -p Type | awk -F= '{print $2}'
}
is_xwindow() {
  local MGR="$(loginctl show-session $(awk '/tty/ {print $1}' <(loginctl)) -p Type | awk -F= '{print $2}' | grep -v x11)"
  test -z "$MGR"
}
is_wayland() {
  local MGR="$(loginctl show-session $(awk '/tty/ {print $1}' <(loginctl)) -p Type | awk -F= '{print $2}' | grep -v wayland)"
  test -z "$MGR"
}
