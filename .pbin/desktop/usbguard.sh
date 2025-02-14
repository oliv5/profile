#!/bin/sh
# https://wiki.archlinux.org/title/USBGuard

usbguard_block_all() {
    sudo usbguard set-parameter ImplicitPolicyTarget block
}

usbguard_allow_all() {
    sudo usbguard set-parameter ImplicitPolicyTarget allow
}

usbguard_show() {
    sudo cat /etc/usbguard/rules.conf
}

usbguard_show_blocked() {
    sudo usbguard list-devices --blocked
}

usbguard_allow_device() {
    sudo usbguard allow-device ${1:?No device ID specified...} ${2:+--permanent}
}

usbguard_list() {
    sudo usbguard generate-policy
}

usbguard_record() {
    sudo sh -c 'usbguard generate-policy > /etc/usbguard/rules.conf'
}

usbguard_add() {
    sudo sh -c 'for RULE; do echo "$RULE" >> /etc/usbguard/rules.conf; done' _ "$@"
}

usbguard_status() {
    sudo systemctl status usbguard
    sudo systemctl status usbguard-dbus
}

usbguard_restart() {
    sudo systemctl restart usbguard
    sudo systemctl restart usbguard-dbus
}

usbguard_start() {
    sudo systemctl start usbguard
    sudo systemctl start usbguard-dbus
}

usbguard_stop() {
    sudo systemctl stop usbguard
    sudo systemctl stop usbguard-dbus
}

usbguard_status() {
    sudo systemctl status usbguard
    sudo systemctl status usbguard-dbus
}

usbguard_disable() {
    usbguard_start
    usbguard_allow
    usbguard_stop
    sudo systemctl disable usbguard
    sudo systemctl disable usbguard-dbus
}

usbguard_enable() {
    usbguard_start
    sudo systemctl enable usbguard
    sudo systemctl enable usbguard-dbus
}

usbguard_help() {
    echo >&2 "usbguard.sh <block_all|allow_all|allow_device|record|show|show_blocked|list|status|disable|enable|start|stop|help>"
}

# Main
"usbguard_${@:-help}"
