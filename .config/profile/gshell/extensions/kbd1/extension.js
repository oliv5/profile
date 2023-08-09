// https://askubuntu.com/questions/1289453/how-do-you-make-a-button-that-performs-a-specific-command
'use strict';

const St = imports.gi.St;

const Main = imports.ui.main;
const Util = imports.misc.util;

let button;

function _myKBD1 () {
    Util.spawnCommandLine("sh -c '$HOME/bin/kbd_action1.sh'")
}

function init() {
    button = new St.Bin({ style_class: 'panel-button',
                          reactive: true,
                          can_focus: true,
                          track_hover: true });

    let icon = new St.Icon ({ icon_name: 'input-keyboard-symbolic',
                      style_class: 'system-status-icon' });

    button.set_child(icon);
    button.connect('button-press-event', _myKBD1);
}

function enable() {
        Main.panel._rightBox.insert_child_at_index(button, 0);
}

function disable() {
        Main.panel._rightBox.remove_child(button);
}

