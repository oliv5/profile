#!/bin/sh
# https://wiki.archlinux.org/title/USBGuard

usbguard_block() {
    sudo usbguard set-parameter ImplicitPolicyTarget block
}

usbguard_allow() {
    sudo usbguard set-parameter ImplicitPolicyTarget allow
}

usbguard_show() {
    cat /etc/usbguard/rules.conf
}

usbguard_list() {
    sudo sh -c 'usbguard generate-policy'
}

usbguard_record() {
    sudo sh -c 'usbguard generate-policy > /etc/usbguard/rules.conf'
}

usbguard_status() {
    sudo systemctl status usbguard
    sudo systemctl status usbguard-dbus
}

usbguard_disable() {
    sudo systemctl start usbguard
    sudo systemctl start usbguard-dbus
    usbguard_allow
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
"usbguard_${@:-help}"
