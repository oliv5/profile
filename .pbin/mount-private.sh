#!/bin/sh
# Try to detect which type of encrypted container is used
DM_CRYPT_FILE="$HOME/.private/private.img"
ECRYPTFS_FILE="$HOME/.private/private.sig"

if [ -x "$HOME/bin/mount_private.sh" ]; then
    echo >&2 "Found local mount_private.sh script !"
    exec "$HOME/bin/mount_private.sh"
elif [ -r "$DM_CRYPT_FILE" ] && file "$DM_CRYPT_FILE" | grep 'LUKS encrypted file' >/dev/null; then
    echo >&2 "Found dmcrypt container !"
    (. "$RC_DIR"/.rc.d/20_mount.sh; mount_private_dmcrypt "$@")
elif [ -f "$ECRYPTFS_FILE" ]; then
    if command -v ecryptfs-simple >/dev/null; then
	echo >&2 "Found ecryptfs container and ecryptfs-simple binary !"
	(. "$RC_DIR"/.rc.d/20_mount.sh; mount_ecryptfs_simple "$@")
    elif command -v mount.ecryptfs_private >/dev/null; then
	echo >&2 "Found ecryptfs container and mount.ecryptfs_private binary !"
	(. "$RC_DIR"/.rc.d/20_mount.sh; mount_ecryptfs_user "$@")
    else
	echo >&2 "Found ecryptfs container !"
	(. "$RC_DIR"/.rc.d/20_mount.sh; mount_ecryptfs "$@")
    fi
else
    echo >&2 "Could not find local mount_private.sh script or any known encrypted private container !"
fi
