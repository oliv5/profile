#!/bin/sh

# Set snap extra files access rights
snap_allow_home() {
  for SNAP; do
    snap connect $SNAP:home
  done
}

# Remove disabled snap (a.k.a cleanup)
# https://www.linuxuprising.com/2019/04/how-to-remove-old-snap-versions-to-free.html
snap_cleanup() {
  ( set -eu
  LANG=en_US.UTF-8 snap list --all | awk '/disabled/{print $1, $3}' |
    while read NAME REV; do
      sudo snap remove "$NAME" --revision="$REV"
    done
  )
}

# Set number of retained snap versions of a package
snap_set_num_retained() {
  sudo snap set system refresh.retain="${1:-2}"
}

# Run a snap command by enabling/disabling the snapd service
snap_exec() {
  sudo sh -c "
    systemctl unmask snapd.service
    systemctl start snapd.service
    systemctl status --no-pager snapd.service
    $(arg_quote "$@")
    systemctl mask snapd.service
    systemctl stop snapd.service
  "
}

# Update snaps by enabling/disabling the snapd service
snap_update() {
  snap_exec snap refresh "$@"
}
snap_update_all() {
  snap_exec snap refresh
}
