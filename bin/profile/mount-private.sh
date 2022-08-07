#!/bin/sh
( set -e
    . "${RC_DIR:-$HOME/.rc.d}/.rc.d/20_mount.sh"
    if mountpoint "$HOME/private"; then
	umount_private_ecryptfs
	echo -e "Press enter..."
	read _
    else
	mount_private_ecryptfs
    fi
)
