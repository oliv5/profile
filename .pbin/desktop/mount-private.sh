#!/bin/sh
( set +e
    . "${RC_DIR:-$HOME/.rc.d}/.rc.d/20_mount.sh"
    if mountpoint "$HOME/private" >/dev/null; then
        echo -n "You are going to unmount your private stash (enter/ctrl-c)..."
        read _
        while mountpoint "$HOME/private"; do
            umount_private_ecryptfs "$HOME/private"
            test $? -ne 0 && sleep 1
        done
    else
        while ! mountpoint "$HOME/private"; do
            mount_private_ecryptfs
            test $? -ne 0 && sleep 1
        done
    fi
)
