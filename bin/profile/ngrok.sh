#!/bin/sh

ngrok_setup_cron() {
    local NTFY_TOPIC="${1:?No NTFY topic ID specified...}"
    sudo tee /etc/cron.d/ngrok-publish-ip <<EOF
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
MAILTO=""
@reboot       root   sleep 1m && /usr/local/bin/ngrok-publish-ip.sh > /var/log/ngrok-publish-ip.log 2>&1
*/5 * * * *   root   /usr/local/bin/ngrok-publish-ip.sh > /var/log/ngrok-publish-ip.log 2>&1
EOF
    sudo tee /usr/local/bin/ngrok-publish-ip.sh <<EOF
#!/bin/sh
# Publish ngrok tunnels in NTFY.sh
NTFY_TOPIC="${NTFY_TOPIC}"

# Check ngrok is installed
if [ \$(systemctl list-unit-files 'ngrok*' | wc -l) -le 3 ]; then
    echo >&2 "ERROR: ngrok service is not installed..."
    exit 1
fi

# Get public tunnel address from ntfy.sh
PUB_TUNNEL="\$(curl -s "https://ntfy.sh/\$NTFY_TOPIC/json?poll=1" | jq -r '.message' | tail -n 1)"

# Find current opened tunnel from ngrok http API
for N in \$(seq 10); do
    CUR_TUNNEL="\$(curl -s http://localhost:4040/api/tunnels | jq -r '.tunnels[0].public_url' | awk -F'tcp://' '/tcp:/ { print \$2 }')"
    if [ -z "\$CUR_TUNNEL" ]; then
        echo >&2 "WARNING: ngrok service not connected, tunnel is down, restarting..." 
        sudo systemctl restart ngrok
        sleep 30
    else
        break
    fi
done

# Publish the current one if different than the published one
if [ -z "\$CUR_TUNNEL" ]; then
    echo >&2 "ERROR: no local tunnel found, cannot publish..."
    exit 2
elif [ "\$PUB_TUNNEL" != "\$CUR_TUNNEL" ]; then
    echo "Old public tunnel : \$PUB_TUNNEL"
    echo "Publish new tunnel : \$CUR_TUNNEL"
    curl -d "\$CUR_TUNNEL" "https://ntfy.sh/$NTFY_TOPIC"
else
    echo "Published tunnel up-to-date: \$PUB_TUNNEL"
fi
EOF
    sudo chmod +x /usr/local/bin/ngrok-publish-ip.sh
}

ngrok_tunnels() {
    local NTFY_TOPIC="${1:?No NTFY topic ID specified...}"
    curl -s "https://ntfy.sh/$NTFY_TOPIC/json?poll=1" | jq -r '.message'
}
ngrok_tunnel() {
    ngrok_tunnels "$@" | tail -n 1
}

ngrok_ssh() {
    local NTFY_TOPIC="${1:?No NTFY topic ID specified...}"
    local USER="$2"
    shift $(($# > 2 ? 2 : $#))
    local TUNNEL="$(ngrok_tunnel "$NTFY_TOPIC")"
    local ADDR="$(echo "$TUNNEL" | cut -d: -f 1)"
    local PORT="$(echo "$TUNNEL" | cut -d: -f 2)"
    PORT="${PORT:-22}"
    if [ "$PORT" = "$TUNNEL" ]; then
	PORT=22
    fi
    : ${TUNNEL:?No tunnel found...}
    ssh -p "$PORT" "${USER:+${USER}@}${ADDR}" "$@"
}

# Main
if [ -n "$1" ]; then ngrok_"$@"; fi
