#!/bin/sh

################################
# Forced actions
force_reboot() {
  # https://stackoverflow.com/questions/31157305/forcing-linux-server-node-to-instantly-crash-and-reboot
  # To enable it you probably need to put following in sysctl.conf:
  # kernel.sysrq = 1
  echo 1 > /proc/sys/kernel/sysrq
  echo b > /proc/sysrq-trigger
}

################################
# Check endianness
# https://serverfault.com/questions/163487/how-to-tell-if-a-linux-system-is-big-endian-or-little-endian
is_littleendian() {
  { echo -n I | od -to2 | awk '{ print substr($2,6,1); exit}'; } 2>/dev/null
  { echo -n I | hexdump -o | awk '{ print substr($2,6,1); exit}'; } 2>/dev/null
}

################################
# Event tester
alias event_list='xev'
alias event_showkey='showkey -s'

################################
# Keyboad layout
alias keyb_list='grep ^[^#] /etc/locale.gen'
alias keyb_set='setxkbmap -layout'
alias keyb_setfr='setxkbmap -layout fr'

# Fix Alt-Fxx keys
# https://bugs.launchpad.net/ubuntu/+source/console-setup/+bug/520546
# https://unix.stackexchange.com/questions/146060/how-to-disable-alt-arrow-switching-of-virtual-consoles#186016
# https://askubuntu.com/questions/805793/how-can-i-disable-the-virtual-terminal-switching-shortcut-keys-in-x/1059609#1059609
keyb_fix_altF_keys() {
  sudo tee -a /etc/console-setup/remap.inc <<EOF
# OLA++
# Immediate but not persistent fix: sudo kbd_mode -s
# Immediate but non persistent fix: sudo sh -c "dumpkeys | grep -Pv '^\s+alt(gr)?\s+keycode\s+\d+\s+=\s+(Console_|Incr_Console|Decr_Console)' | loadkeys"
# Immediate but not persistent fix: sudo sh -c 'dumpkeys | grep -v cr_Console | loadkeys'
# This is a permanent fix. Apply + `sudo dpkg-reconfigure console-setup -phigh` + reboot
# Remap alt+Fxx key to void to avoid terminal switching
alt     keycode  67 = VoidSymbol
alt     keycode  68 = VoidSymbol
alt     keycode  69 = VoidSymbol
alt     keycode  70 = VoidSymbol
alt     keycode  71 = VoidSymbol
alt     keycode  72 = VoidSymbol
alt     keycode  73 = VoidSymbol
alt     keycode  74 = VoidSymbol
alt     keycode  75 = VoidSymbol
alt     keycode  76 = VoidSymbol
alt     keycode  77 = VoidSymbol
alt     keycode  78 = VoidSymbol
# Also remove mapping for alt left arrow and right arrow
alt     keycode 113 = VoidSymbol
alt     keycode 114 = VoidSymbol
EOF
  sudo dpkg-reconfigure console-setup -phigh
  echo "Need a reboot... apply a temporary not persistent fix"
  sudo dumpkeys | grep -Pv '^\s+alt(gr)?\s+keycode\s+\d+\s+=\s+(Console_|Incr_Console|Decr_Console)' | sudo loadkeys
  echo "done!"
}

################################
# Get XWindow ID
xwmid() {
  xwininfo | awk '/xwininfo: Window id:/ {print $4}'
}
# Get XWindow PID
xwmpid() {
  xprop -id "${1:-$(xwmid)}" | awk '/WM_PID/ {print $3}'
}
# My xkill
command -v xkill >/dev/null ||
xkill() {
  xwmid | xargs -r xdotool windowkill
}
# Close Xwindow
xclose() {
  xwmid | xargs -r xdotool windowclose
}

################################
# Chroot
mkchroot(){
  local DIR="${1:?No chroot directory specified...}"
  local DISTR="${2:?No distribution name specified...}"
  local ARCH="$3"
  local PKG_COMPONENTS="${4:-main}" # Ubuntu: main,restricted,universe,multiverse Debian: contrib,non-free
  shift $(($# < 4 ? $# : 4))
  sudo debootstrap ${ARCH:+--arch="$ARCH" --foreign} ${components:+--components="$PKG_COMPONENTS"} "$DISTR" "$DIR" "$@"
}

enterchroot() {
  local DIR="${1:?No chroot directory specified...}"
  mount --bind "/dev" "$DIR/dev"
  mount --bind "/dev/pts" "$DIR/dev/pts"
  mount -t sysfs "/sys" "$DIR/sys"
  mount -t proc "/proc" "$DIR/proc"
  sudo chroot "$DIR"
}

# Schroot
mkschroot() { # alternative is: mk-sbuild --target arm64 bionic && schroot -u root -c bionic-amd64-arm64
  local DIR="${1:?No chroot directory specified...}"
  local DISTR="${2:?No distribution name specified...}"
  local ARCH="$3"
  local PROFILE="${4:-default}"
  local PKG_COMPONENTS="${5:-main}" # Ubuntu: main,restricted,universe,multiverse Debian: contrib,non-free
  local NAME="$(basename "$DIR")"
  local CONF="/etc/schroot/chroot.d/$NAME"
  shift $(($# < 4 ? $# : 4))
  sudo mkdir -p "$DIR" || { echo >&2 "Cannot create chroot directory... Abort !" && return 1; }
  sudo mkdir -p "/etc/schroot/chroot.d/" || { echo >&2 "Cannot create schroot config directory... Abort !" && return 2; }
  sudo tee "$CONF" <<EOF
# schroot chroot definitions.
# See schroot.conf(5) for complete documentation of the file format.
#
# Please take note that you should not add untrusted users to
# root-groups, because they will essentially have full root access
# to your system.  They will only have root access inside the chroot,
# but that is enough to cause malicious damage.
#
[$NAME]
description=Chroot for $NAME
type=directory
directory=$(readlink -f "$DIR")
users=$(whoami)
root-users=root
root-groups=root
profile=$PROFILE
#aliases=default
EOF
  sudo debootstrap ${ARCH:+--arch="$ARCH" --foreign} ${components:+--components="$PKG_COMPONENTS"} "$@" "$DISTR" "$DIR"
}

# https://askubuntu.com/questions/148638/how-do-i-enable-the-universe-repository
# https://manpages.ubuntu.com/manpages/trusty/man1/add-apt-repository.1.html
mkschroot_stage2() {
  local NAME="${1:?No chroot name specified...}"
  local CONF="/etc/schroot/chroot.d/$NAME"
  local DIR="$(awk -F= '/directory=/ {print $2}' "$CONF")"

  # Change the schroot type, create type "custom" if not existing already
  if ! [ -d /etc/schroot/custom ]; then
    sudo cp -r /etc/schroot/default /etc/schroot/custom
    # Stop resetting passwd/group files every time
    sudo sed -i -e '/passwd/d; /shadow/d; /group/d; /gshadow/d' /etc/schroot/custom/copyfiles
    sudo sed -i -e '/passwd/d; /shadow/d; /group/d; /gshadow/d' /etc/schroot/custom/nssdatabases
  fi
  sudo sed -i -e 's/profile=.*/profile=custom/ ; s/^union-type=/#union-type=/' "/etc/schroot/chroot.d/$NAME"
  # Copy the passwd/group files once
  sudo cp -v /etc/passwd /etc/shadow /etc/group /etc/gshadow "$DIR/etc/"

  # Case using qemu user emulation
  local ARCH="$(sudo schroot -u root -c "$NAME" -- uname -m)"
  if [ -n "$ARCH" ] && [ "$ARCH" != "$(uname -m)" ]; then
    # See https://wiki.ubuntu.com/ARM/RootfsFromScratch/QemuDebootstrap
    # Copy qemu binary
    if [ "$ARCH" != "aarch64" ]; then
      sudo cp -v /usr/bin/qemu-arm-static "$DIR/usr/bin/"
    else
      echo >&2 "Not supported: You must add the relevant qemu binary copy in this script..."
      return 1
    fi
    # Run second stage
    sudo schroot -u root -c "$NAME" -- /debootstrap/debootstrap --second-stage
  fi

  # Finalize
  sudo schroot -u root -c "$NAME" -- sh -c ':; set -e
    # Set main user password and test it with sudo
    echo "Set user password for $1..."
    passwd "$1"
    echo "Test user password..."
    su "$1" -c "echo OK"
  ' _ "$(whoami)"

  # Allow sudo with no password in foreign architectures
  if [ -n "$ARCH" ] && [ "$ARCH" != "$(uname -m)" ]; then
    sudo schroot -u root -c "$NAME" -- sh -c ':; set -e
      echo "Allow user sudo without password because of issue with tty/askpass..."
      echo "NOTE: an incomplete alternative is to use sudo -S"
      echo "$1 ALL = NOPASSWD: ALL" | EDITOR="tee" visudo "/etc/sudoers.d/$1"
      echo "Test sudo without password..."
      sudo echo "OK"
    ' _ "$(whoami)"
  fi

}

# Remove schroot
rmschroot() {
  local NAME
  schroot --all-session --end-session
  for NAME; do
    NAME="$(echo $NAME | cut -d: -f2)"
    local CONF="/etc/schroot/chroot.d/$NAME"
    [ -r "$CONF" ] || { echo >&2 "Unknown chroot '$NAME'..."; continue; }
    echo -n "Remove the schroot folder with: sudo rm -rI "
    awk -F= '/directory=/ {print $2}' "$CONF"
    sudo rm "$CONF" 2>/dev/null
  done
}

################################
# Fstab to autofs conversion
fstab2autofs() {
  awk 'NF && substr($1,0,1)!="#" {print $2 "\t-fstype="$3 "," $4 "\t" $1}' "$@"
}

################################
# Add to user crontab
cron_useradd() {
  (crontab -l; echo "$@") | crontab -
}
# Add to system crontab
cron_sysadd() {
  sudo sh -c 'echo "$@" >> "/etc/cron.d/$USER"'
}

################################
# Setup user anacron
# https://askubuntu.com/questions/235089/how-can-i-run-anacron-in-user-mode
anacron_usersetup() {
  local DIR="${1:-$HOME}"
  mkdir -p "$DIR/.anacron/etc"
  mkdir -p "$DIR/.anacron/spool"
  [ ! -e "$DIR/.anacron/etc/anacrontab" ] && cat > "$DIR/.anacron/etc/anacrontab" <<EOF
# /etc/anacrontab: configuration file for anacron

# See anacron(8) and anacrontab(5) for details.

SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

# period  delay  job-identifier  command
#1         10     testjob         test.sh
EOF
  if ! crontab -l | grep "@hourly /usr/sbin/anacron" >/dev/null; then
    echo "Register anacron in user crontab"
    cron_useradd "@hourly /usr/sbin/anacron -s -t $HOME/.anacron/etc/anacrontab -S $HOME/.anacron/spool"
  fi
}

################################
# Rename current logged on user and its group
user_rename_current_user() {
  local OLDNAME="${1:?Old name not specified...}"
  local NEWNAME="${2:?New name not specified...}"
  local DESCR="${3:-$NEWNAME}"
  local CURNAME="$(whoami)"
  echo "List of commands to carry on:"
  echo
  cat <<EOF
exit
ssh $CURNAME@$HOSTNAME "sudo useradd tempuser; sudo passwd tempuser; sudo usermod -a -G sudo tempuser"
ssh tempuser@$HOSTNAME "/bin/sh -c '$(type user_rename | tail -n +2); user_rename $OLDNAME $NEWNAME $DESCR'"
ssh $CURNAME@$HOSTNAME "sudo userdel tempuser"
EOF
}

# Rename another user and its group
user_rename() {
  local OLDNAME="${1:?Old name not specified...}"
  local NEWNAME="${2:?New name not specified...}"
  local DESCR="${3:-$NEWNAME}"
  local CURNAME="$(whoami)"
  if [ "$CURNAME" = "$OLDNAME" ]; then
    echo "Cannot rename the current logged on user."
    user_rename_current_user "$@"
    return 1
  else
    sudo killall -u "$OLDNAME"
    sudo id "$OLDNAME"
    sudo usermod -l "$NEWNAME" "$OLDNAME"
    sudo groupmod -n "$NEWNAME" "$OLDNAME"
    sudo usermod -d /home/"$NEWNAME" -m "$NEWNAME"
    sudo usermod -c "$DESCR" "$NEWNAME"
    sudo id "$NEWNAME"
    return 0
  fi
}

################################
# List kernel modules
alias kernel_lsmod='find /lib/modules/$(uname -r) -type f -name "*.ko*"'
alias kernel_lsmodg='find /lib/modules/$(uname -r) -type f -name "*.ko*" | grep'
kernel_lsmodk() {
  for MOD; do
    grep "$MOD" /lib/modules/$(uname -r)/modules.dep
  done
}

################################
# https://www.cyberciti.biz/tips/linux-security.html
# List accounts with empty passwords
empty_passwd() {
  awk -F: '($2 == "") {print}' /etc/shadow
}

empty_uid() {
  awk -F: '($3 == "0") {print}' /etc/passwd
}

################################
# Bumblebee commands
# https://github.com/Bumblebee-Project/bbswitch
alias bb_status='cat /proc/acpi/bbswitch'
alias bb_on='sudo sh -c "echo ON > /proc/acpi/bbswitch"'
alias bb_off='sudo sh -c "echo OFF > /proc/acpi/bbswitch"'

################################
# nvidia-prime commands
alias primerun='DRI_PRIME=1'

################################
# inotify helpers
alias notify_write='notify close_write'
alias notify_read='notify close_read'
alias notify_rw='notify "close_read,close_write"'
alias notify_create='notify create'
alias notify_mv='notify moved_to'
alias notify='inotify_loop'

# Basic notification method with a loop
# Pros: file move is captured
# Cons: may miss event, high system resource consumption on large directories
inotify_loop() {
  local TRIGGER="${1:?No event to monitor}"
  local FILE="${2:?No dir/file to monitor}"
  shift 2
  local SCRIPT="${@:?No action to execute}"
  sh -c "while true; do inotifywait -qq -e \"$TRIGGER\" \"$FILE\"; eval \"$SCRIPT\"; done" &
}

################################
# List displays
# https://unix.stackexchange.com/questions/17255/is-there-a-command-to-list-all-open-displays-on-a-machine
lsdisplay() {
  # Local display
  (cd /tmp/.X11-unix && for x in X*; do echo ":${x#X}"; done)
  # Remote displays (open TCP ports above 6000)
  netstat -lnt | awk '
  sub(/.*:/,"",$4) && $4 >= 6000 && $4 < 6100 {
    print ($1 == "tcp6" ? "ip6-localhost:" : "localhost:") ($4 - 6000)
  }'
  # Show which program has port 60xx opened
  lsof -i -n | awk '$9 ~ /:60[0-9][0-9]$/ {print}'
}

################################
# Get/check battery status
bat_charging_level() {
  sudo cat "${1:-/sys/class/power_supply/battery/capacity}"
}
bat_charging_status() {
  sudo cat "${1:-/sys/class/power_supply/battery/status}" #| tr '[:upper:]' '[:lower:]'
}

################################
# Add into sudoers.d/
sudoers_nopasswd() {
    local CMD="${1:?No command specified...}"
    local USER="${2:-%sudo}"
    local NAME="${3:-noname_$(date +%s)}"
    echo "$USER ALL = NOPASSWD: $CMD" | sudo EDITOR="tee" visudo "/etc/sudoers.d/$NAME"
}
