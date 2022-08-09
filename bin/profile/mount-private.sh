#!/bin/sh
( set -e
    . "${RC_DIR:-$HOME/.rc.d}/.rc.d/20_mount.sh"
    if mountpoint "$HOME/private"; then
	echo -n "You are going to unmount your private stash (enter/ctrl-c)..."
	read _
	umount_private_ecryptfs
    else
	mount_private_ecryptfs
    fi
)
