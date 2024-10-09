#!/bin/sh

# Start SSH agent if not running
if ! ssh-add -l >/dev/null 2>&1; then
    echo "Start SSH agent"
    eval $(ssh-agent)
    if ! ssh-add -l >/dev/null 2>&1; then
	echo >&2 "ERROR: cannot load ssh-agent. Abort..."
	exit 1
    fi
fi

# Load keys from command line
for KEY; do
    if [ "${KEY##*/}" = "$KEY" ]; then
	KEY="$HOME/.ssh/$KEY"
    fi
    if ! [ -f "$KEY" ]; then
	echo >&2 "ERROR: private SSH key '$KEY' does not exist. Abort..."
	exit 1
    fi
    if ! [ -f "${KEY}.pub" ]; then
	echo >&2 "ERROR: public SSH key '${KEY}.pub' does not exist. Abort..."
	exit 1
    fi
    if ! ssh-add -L | grep -F -- "$(cat "${KEY}.pub" | cut -d' ' -f 1,2)" >/dev/null 2>&1; then
	echo "Load key '$KEY'"
	if ! ssh-add -t 1h "$KEY"; then
	    echo >&2 "ERROR: cannot load SSH key '$KEY'. Abort..."
	    exit 1
	fi
    fi
done
