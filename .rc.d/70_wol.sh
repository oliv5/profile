#!/bin/sh
#https://doc.ubuntu-fr.org/wakeonlan
#https://www.oueta.com/linux/check-and-enable-wake-on-lan-in-linux/

# List status
wol_status() {
    sudo ethtool ${1:-eth0} | grep "Wake-on:"
}

# Enable wol
wol_enable() {
    sudo ethtool -s ${1:-eth0} wol g
}

# Disable wol
wol_disable() {
    sudo ethtool -s ${1:-eth0} wol d
}

# Send wol packet
wol_send() {
    local MAC="${1?No MAC specified...}"
    local DST="${2?No IP address, DNS name nor network interface specified...}"
    local PORT="${3:-9}"
    local NET="${4:-wan}"
    local PASS="$5"
    MAC="${MAC//-/:}"
    if [ "$NET" = "http" ]; then
        MAC="${MAC//:/}"
        URI="https://www.depicus.com/wake-on-lan/woli?m=${MAC}&i=${DST}&s=255.255.255.255&p=${PORT}"
        #URI="http://www.wakeonlan.me/?mobile=0&ip=${DST}:${PORT}&mac=${MAC}&pass=${PASS}&schedule=&timezone=0"
        if command -v curl >/dev/null 2>&1; then
          curl "${URI}" >/dev/null
        elif command -v wget >/dev/null 2>&1; then
          wget "${URI}" -q -O /dev/null
        else
          echo "No appropriate WOL software available..."
        fi
    else
        if command -v wakeonlan >/dev/null 2>&1; then
          wakeonlan -i ${DST} -p ${PORT} ${MAC}
        elif command -v wol >/dev/null 2>&1; then
          wol -i ${DST} -p ${PORT} ${MAC}
        elif command -v etherwake >/dev/null 2>&1; then
          etherwake -i ${DST} -b ${MAC}
        else
          echo "No appropriate WOL software available..."
        fi
    fi
}

# Enable wol persistently
wol_persistent_init() {
    sudo sh -c 'cat > /etc/init/wol <<EOF
start on started network

script
    for ITF; do
        logger -t "wakeonlan init script" enabling wake on lan for \$interface
        ethtool -s "\$ITF" wol g
    done
end script
EOF
' _ ${@:-$(cut -d: -f1 /proc/net/dev | tail -n +3 | tr -d ' ')}
}

wol_persistent_networkmanager() {
    for CONNECTION; do
        sudo nmcli connection modify "$CONNECTION" 802-3-ethernet.wake-on-lan magic
        sudo nmcli connection up "$CONNECTION"
    done
}

wol_persistent_rc_local() {
    for ITF in ${@:-$(cut -d: -f1 /proc/net/dev | tail -n +3 | tr -d ' ')}; do
        cat >> /etc/rc.local <<EOF
# Enable wol
if [ -z "$(ethtool "$ITF" | grep "Wake-on: g")" ]; then
    ethtool -s "$ITF" wol g
fi
true
EOF
    done
}

########################################
########################################
# Last commands in file
# Execute function from command line
[ "${1#wol}" != "$1" ] && "$@" || true
