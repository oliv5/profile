#!/bin/sh
( . "$RC_DIR/.rc.d/20_mount.sh"
mount_private_ecryptfs
)
