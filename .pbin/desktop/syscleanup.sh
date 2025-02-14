#!/bin/sh

# Systemd logs
if command -v journalctl >/dev/null; then
    sudo journalctl --vacuum-size=500M
    sudo mkdir -p /etc/systemd/journald.conf.d
    cat <<EOF | tee /etc/systemd/journald.conf.d/maxsize.conf
[Journal]
SystemMaxUse=500M
RuntimeMaxUse=500M
EOF
fi

# Snap config
if command -v snap >/dev/null; then
    sudo snap set system refresh.retain=2
    # Removes old revisions of snaps
    # CLOSE ALL SNAPS BEFORE RUNNING THIS
    (set -eu
    snap list --all | awk '/disabled/{print $1, $3}' |
	while read snapname revision; do
	    snap remove "$snapname" --revision="$revision"
	done
    )
fi
