#!/bin/sh
# https://wiki.archlinux.org/title/USBGuard

usbguarg_block() {
    sudo usbguard set-parameter ImplicitPolicyTarget block
}

usbguarg_allow() {
    sudo usbguard set-parameter ImplicitPolicyTarget allow
}

usbguarg_show() {
    cat /etc/usbguard/rules.conf
}

usbguarg_list() {
    sudo sh -c 'usbguard generate-policy'
}

usbguarg_record() {
    sudo sh -c 'usbguard generate-policy > /etc/usbguard/rules.conf'
}

usbguard_status() {
    sudo systemctl status usbguard
    sudo systemctl status usbguard-dbus
}

usbguard_disable() {
    sudo systemctl start usbguard
    sudo systemctl start usbguard-dbus
    usbguarg_allow
    sudo systemctl stop usbguard
    sudo systemctl stop usbguard-dbus
    sudo systemctl disable usbguard
    sudo systemctl disable usbguard-dbus
}

usbguard_enable() {
    sudo systemctl enable usbguard
    sudo systemctl enable usbguard-dbus
}

usbguard_help() {
    echo >&2 "usbguard.sh <block|allow|record|show|list|status|disable|enable|help>"
}

# Main
if [ -n "$1" ]; then
    "usbguard_$@"
fi
