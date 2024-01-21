#!/bin/sh
# Opens a mosh session using a proxy. Uses a socat UDP relay. Inspired from https://gist.github.com/tribut/5285883
#
# Usage: mosh-proxy.sh ssh-remote-name [ssh config file] [proxy address[:port]] [target address]
# 
# Pre-requisites
#  - a valid plain-SSH connection to the target machine. Can be using SSH "proxycommand" statement in the SSH config file.
#  - a valid plain-SSH connection to the proxy machine
#  - local packages: ssh mosh awk ansifilter
#  - proxy packages: socat
#  - target packages: ssh mosh
#
# Drawbacks
#  - the regex extracting the proxy address from the SSH config file is looking for IPv4 address only; it does not recognize host names or IPv6
#  - socat inactivity timeout does not work, so we have to kill socat processes (our user only) on the proxy machine during mosh shutdown
#
REMOTE="${1:-${REMOTE}}"
SSH_CONFIG="${2:-${SSH_CONFIG:-$HOME/.ssh/config}}"
PROXY_ADDR="${3%:*}"
PROXY_PORT="${3#*:}"
TGT_ADDR="${4%:*}"

if [ -z "$REMOTE" ]; then
	echo >&2 "No ssh remote host name specified..."
	exit 1
fi

# Get proxy address and port from SSH config. Looks for "host" and "proxycommand" statements
if [ -z "$PROXY_ADDR" ]; then
	PROXY_ADDR="$(awk '
		BEGIN{IGNORECASE=1; found=0}
		found==0 && match($0,/^(match )?host '$REMOTE'\s?/){found=1; next}
		found==1 && match($0,/^(match )?host\s?/){exit(0)}
		found==1 && /proxycommand/ && match($0,/([0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3})/,groups) {print groups[1]; exit(0)}
	' "$SSH_CONFIG")"
	if [ -z "$PROXY_ADDR" ]; then
		echo >&2 "got no proxy address..."
		exit 1
	fi
fi

if [ -z "$PROXY_PORT" ]; then
	PROXY_PORT="$(awk '
		BEGIN{IGNORECASE=1; found=0}
		found==0 && match($0,/^(match )?host '$REMOTE'\s?/){found=1; next}
		found==1 && match($0,/^(match )?host\s?/){exit(0)}
		found==1 && /proxycommand/ && match($0,/-p ([0-9]*)/,groups) {print groups[1]; exit(0)}
	' "$SSH_CONFIG")"
	if [ -z "$PROXY_PORT" ]; then
		PROXY_PORT=22
	fi
fi

# Get target address from SSH config. Looks for "host" and "hostname" statements
if [ -z "$TGT_ADDR" ]; then
	TGT_ADDR="$(awk '
		BEGIN{IGNORECASE=1; found=0}
		found==0 && match($0,/^(match )?host '$REMOTE'\s?/){found=1; next}
		found==1 && match($0,/^(match )?host\s?/){exit(0)}
		found==1 && /hostname/ && match($0,/hostname (.*)/,groups) {print groups[1]; exit(0)}
	' "$SSH_CONFIG")"
	if [ -z "$TGT_ADDR" ]; then
		echo >&2 "got no target address..."
		exit 1
	fi
fi

# Start mosh-server on the target using exising ssh proxycommand
echo "start remote mosh-server"
MOSH_DATA="$(ssh -qt "$REMOTE" mosh-server new | grep '^MOSH' | ansifilter)"
if [ -z "$MOSH_DATA" ]; then
	echo >&2 "mosh-server could not be started..."
	exit 1
fi

# Extract mosh server information
MOSH_PORT="$(echo -n $MOSH_DATA | cut -s -d' ' -f3)"
MOSH_KEY="$(echo -n $MOSH_DATA | cut -s -d' ' -f4)"
if [ -z "$MOSH_PORT" -o -z "$MOSH_KEY" ]; then
	echo >&2 "got no parseable answer"
	exit 1
fi

echo "mosh proxy: $PROXY_ADDR:$PROXY_PORT"
echo "mosh relay: localhost:$MOSH_PORT <-> $PROXY_ADDR:$MOSH_PORT <-> $TGT_ADDR:$MOSH_PORT"

# Start socat proxy
echo "start socat proxy"
ssh -qp "$PROXY_PORT" "$PROXY_ADDR" "nohup socat -T 60 UDP-LISTEN:$MOSH_PORT,fork,reuseaddr,range=\$(echo \$SSH_CLIENT | cut -d ' ' -f 1)/32 UDP:$TGT_ADDR:$MOSH_PORT >/dev/null 2>&1 &"
sleep 1

# Start mosh-client
echo "start local mosh-client"
MOSH_KEY="$MOSH_KEY" mosh-client "$PROXY_ADDR" "$MOSH_PORT"; RET=$?
MOSH_PORT=""
MOSH_KEY=""

# Cleaning
echo "clean socat proxy processes"
ssh -qp "$PROXY_PORT" "$PROXY_ADDR" killall -q socat

# The end
(exit $RET)
