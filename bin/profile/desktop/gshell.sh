#!/bin/sh
# Gnome shell commands

# Simulate Alt+F2, r
gshell_replace_auto() {
  xdotool key "Alt+F2+r" && sleep 0.5 && xdotool key "Return"
}

# Reload gnome-shell the hard way
# Better use: Alt+F2, r
gshell_replace() {
  DISPLAY=${1:-:0} gnome-shell --replace &
}

# Send SIGQUIT to gshell
ghell_sigquit() {
  killall -SIGQUIT gnome-shell
}

# Restart gnome-shell the hard way
gshell_restart() {
  sudo systemctl restart lightdm 2>/dev/null ||
    sudo systemctl restart gdm3 2>/dev/null
}

gshell_install_utils() {
  local BINDIR="$HOME/.local/bin"
  wget -O "$BINDIR/gnome-shell-extension-installer" "https://github.com/brunelli/gnome-shell-extension-installer/raw/master/gnome-shell-extension-installer" &&
    chmod +x "$BINDIR/gnome-shell-extension-installer"
  git clone https://gitlab.com/thjderjktyrjkt/disable-gnome-extension-update-check.git "$HOME/.local/share/gnome-shell/extensions/disable-gnome-extension-update-check@thjderjktyrjkt.gitlab.com"
}

# See https://unix.stackexchange.com/questions/86221/how-can-i-lock-my-screen-in-gnome-3-without-gdm#86275
gnome_lock() {
  if command -v gnome-screensaver-command >/dev/null; then
    gnome-screensaver-command --lock
  else
    dbus-send --type=method_call --dest=org.gnome.ScreenSaver \
      /org/gnome/ScreenSaver org.gnome.ScreenSaver.Lock
  fi
}

# Execute command when any
[ $# -gt 0 ] && gshell_"$@"
