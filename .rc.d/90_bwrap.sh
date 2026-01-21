#!/bin/bash
# https://github.com/containers/bubblewrap/blob/main/demos/bubblewrap-shell.sh

# With dash redirections, but the command executed is not interactive
#bubblewrap() {
#  ( getent passwd $UID 65534 |
#    ( getent group $(id -g) 65534 |
#      ( exec bwrap \
#          --ro-bind /usr /usr \
#          --dir /tmp \
#          --dir /var \
#          --symlink ../tmp var/tmp \
#          --proc /proc \
#          --dev /dev \
#          --ro-bind /etc/resolv.conf /etc/resolv.conf \
#          --symlink usr/lib /lib \
#          --symlink usr/lib64 /lib64 \
#          --symlink usr/bin /bin \
#          --symlink usr/sbin /sbin \
#          --chdir / \
#          --unshare-all \
#          --share-net \
#          --die-with-parent \
#          --dir /run/user/$(id -u) \
#          --setenv XDG_RUNTIME_DIR "/run/user/$(id -u)" \
#          --setenv PS1 "bwrap$ " \
#          --file 11 /etc/passwd \
#          --file 12 /etc/group \
#          -- "$@" ) \
#      12<&0 ) \
#    11<&0 )
#}

# With intermediate files
bubblewrap() {
  local F1="$(umask 022; mktemp)"
  local F2="$(umask 022; mktemp)"
  getent passwd $UID 65534 > "$F1"
  getent group $(id -g) 65534 > "$F2"
  bwrap --ro-bind /usr /usr \
      --dir /tmp \
      --dir /var \
      --symlink ../tmp var/tmp \
      --proc /proc \
      --dev /dev \
      --ro-bind /etc/resolv.conf /etc/resolv.conf \
      --symlink usr/lib /lib \
      --symlink usr/lib64 /lib64 \
      --symlink usr/bin /bin \
      --symlink usr/sbin /sbin \
      --chdir / \
      --unshare-all \
      --share-net \
      --die-with-parent \
      --dir /run/user/$(id -u) \
      --setenv XDG_RUNTIME_DIR "/run/user/`id -u`" \
      --setenv PS1 'bwrap$ ' \
      --ro-bind "$F1" /etc/passwd \
      --ro-bind "$F2" /etc/group \
      -- "$@"
  rm "$F1" "$F2"
}
