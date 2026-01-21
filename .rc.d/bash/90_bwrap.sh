#!/bin/bash
# Bubblewrap
# https://github.com/containers/bubblewrap/blob/main/demos/bubblewrap-shell.sh

bubblewrap() {
  ( exec bwrap \
      --ro-bind /usr /usr \
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
      --setenv XDG_RUNTIME_DIR "/run/user/$(id -u)" \
      --setenv PS1 'bwrap$ ' \
      --file 11 /etc/passwd \
      --file 12 /etc/group \
      -- "$@" ) \
    11< <(getent passwd $UID 65534) \
    12< <(getent group $(id -g) 65534)
}
