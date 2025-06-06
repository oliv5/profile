#!/bin/sh

# Aliases
alias remount_rw='sudo mount -o remount,rw'
alias remount_ro='sudo mount -o remount,ro'

# Mount checker
_mounted_one() {
  local PATTERN="${1:?No pattern specified...}"
  local MOUNT="$(mount)"
  shift 1
  for M; do
    echo "$MOUNT" | grep "on $M " | grep -q -e "$PATTERN" && return 0 # one mounted
  done
  return 1 # none mounted
}
_mounted_all() {
  local PATTERN="${1:?No pattern specified...}"
  local MOUNT="$(mount)"
  shift 1
  for M; do
    echo "$MOUNT" | grep "on $M " | grep -q -e "$PATTERN" || return 1 # not all mounted
  done
  return 0 # all mounted
}
mounted() { _mounted_all " " "$@"; }
mounted_rw() { _mounted_one "[(\s,]rw[\s,)]" "$@"; }
mounted_ro() { _mounted_one "[(\s,]ro[\s,)]" "$@"; }
mounted_net() { _mounted_one "type \(cifs\|nfs\|fuse.sshfs\)" "$@"; }
mounted_nfs() { _mounted_one "type nfs" "$@"; }
mounted_cifs() { _mounted_one "type cifs" "$@"; }
mounted_sshfs() { _mounted_one "type fuse.sshfs" "$@"; }
mounted_autofs() { _mounted_one "type autofs" "$@"; }

# Mount cleaner
# Keep a number of mounts matching input regex
mount_cleaner() {
  local SEARCH="${1:?No mount specified...}"
  local WANTED="${2:-0}"
  local COUNT="$(mount | grep -e "$SEARCH" | wc -l)"
  sudo root "
    mount | grep -e '$SEARCH' | cut -d ' ' -f 3 | 
      while IFS= read -r MOUNT && [ $COUNT -gt $WANTED ]; do
        COUNT=$((COUNT - 1))
        umount '$MOUNT'
      done
  "
}

#####################################
# https://wiki.archlinux.org/index.php/ECryptfs#Encrypting_a_data_directory
# https://wiki.archlinux.org/index.php/ECryptfs#Manual_setup

############
# Mount helpers
ecryptfs_wrap_passphrase() {
  local FILE="${1:-$HOME/.private/wrapped-passphrase}"
  ( stty -echo; printf "Passphrase: " 1>&2; read PASSWORD; stty echo; echo "$PASSWORD"; ) |
    xargs printf "%s\n%s" $(od -x -N 100 --width=30 /dev/random | head -n 1 | sed "s/^0000000//" | sed "s/\s*//g") |
    ecryptfs-wrap-passphrase "$FILE"
}
ecryptfs_unwrap_passphrase() {
  local FILE="${1:-$HOME/.private/wrapped-passphrase}"
  ( stty -echo; printf "Passphrase: " 1>&2; read PASSWORD; stty echo; echo "$PASSWORD"; ) |
    ecryptfs-insert-wrapped-passphrase-into-keyring "$FILE" -
}

############
# Setup ecryptfs encryption
setup_ecryptfs() {
  local SRC="${1:?Missing source directory...}"
  local DST="${2:?Missing dest directory...}"
  local SIG="${3:-$SRC/private.sig}"
  # Ecryptfs cannot be used recursively
  # Special case: home folder is already encrypted and SRC/DST are within
  if grep "$HOME" /proc/mounts | grep -i ecryptfs >/dev/null; then
    if echo "$SRC" | grep "$HOME" >/dev/null; then
      echo >&2 "Error: ecryptfs cannot be used recursively; HOME folder is already encrypted. Abort..."
      return 1
    fi
  fi
  if [ -e "$SIG" ]; then
    echo >&2 "Error: signature file $SIG exists already. Abort..."
    return 1
  fi
  mkdir -p "$SRC"
  echo -n "Passphrase 1: "
  local KEY1="$(ecryptfs-add-passphrase | grep -oE '\[.*\]' | tr -d '[]')"
  echo -n "Passphrase 2: "
  local KEY2="$(ecryptfs-add-passphrase | grep -oE '\[.*\]' | tr -d '[]')"
  echo $KEY1 > "$SIG"
  echo $KEY2 >> "$SIG"
}

############
# Raw mount ecryptfs using root
mount_ecryptfs_root() {
  local SRC="${1:?Missing source directory...}"
  local DST="${2:?Missing dest directory...}"
  local KEY1="${3:?Missing content key...}"
  local KEY2="${4:-$KEY1}"
  local CIPHER="${5:-aes}"
  local KEYLEN="${6:-32}"
  shift $(($# < 6 ? $# : 6))
  local OPT="$@"
  local VERSION="$(ecryptfsd -V | awk '{print $3;exit}' | bc)"
  if [ $VERSION -lt 111 ]; then
    local OPT="key=passphrase,ecryptfs_enable_filename_crypto=yes,no_sig_cache=yes${@:+,$@}"
  fi
  OPT="ecryptfs_cipher=$CIPHER,ecryptfs_key_bytes=$KEYLEN,ecryptfs_sig=$KEY1,ecryptfs_fnek_sig=$KEY2,ecryptfs_unlink_sigs,ecryptfs_passthrough=no${OPT:+,$OPT}"
  if [ "$SRC" = "$DST" ]; then
    echo "ERROR: same source and destination directories."
    return 1
  fi
  chmod 700 "$SRC"
  if [ $VERSION -lt 111 ]; then
    sudo ecryptfs-add-passphrase --fnek
    sudo mount -i -t ecryptfs -o "$OPT" "$SRC" "$DST"
  else
    sudo mount -t ecryptfs -o "$OPT" "$SRC" "$DST"
  fi
  chmod 770 "$DST"
}
umount_ecryptfs_root() {
  sudo umount -f "${1:?Missing mounted directory...}" ||
    sudo umount -l "${1:?Missing mounted directory...}"
  sudo keyctl clear @u
  sudo keyctl clear @s
}

############
# User mount ecryptfs (no root)
# Mount options are hardcoded: AES, key 16b
# See https://github.com/dustinkirkland/ecryptfs-utils/blob/master/src/utils/mount.ecryptfs_private.c
mount_ecryptfs_user() {
  local SRC="${1:?Missing source directory...}"
  local DST="${2:?Missing dest directory...}"
  local KEY1="${3:?Missing content key...}"
  local KEY2="${4:-$KEY1}"
  local CONFNAME="${7:-private}"
  local CONF="$HOME/.private/$CONFNAME.conf"
  local SIG="$HOME/.private/$CONFNAME.sig"
  chmod 700 "$HOME/.ecryptfs"
  ecryptfs-add-passphrase --fnek
  keyctl link @u @s # Workaround for FS#55943 (https://bugs.archlinux.org/task/55943). See https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=870126#10
  echo "$SRC $DST ecryptfs" > "$CONF"
  echo "$KEY1" > "$SIG"
  echo "$KEY2" >> "$SIG"
  mount.ecryptfs_private "$CONFNAME"
  chmod 770 "$DST"
}
umount_ecryptfs_user() {
  local CONFNAME="$(basename "${1:-private}")"
  umount.ecryptfs_private "$CONFNAME"
  keyctl clear @u
  keyctl clear @s
}

############
# User mount using ecryptfs-simple (no root)
# https://xyne.dev/projects/ecryptfs-simple/
# https://github.com/mhogomchungu/ecryptfs-simple
# http://download.opensuse.org/repositories/home:/obs_mhogomchungu/
mount_ecryptfs_simple() {
  local SRC="${1:?Missing source directory...}"
  local DST="${2:?Missing dest directory...}"
  local KEY1="${3:?Missing content key...}"
  local KEY2="${4:-$KEY1}"
  local CIPHER="${5:-aes}"
  local KEYLEN="${6:-32}"
  shift $(($# < 6 ? $# : 6))
  local OPT="ecryptfs_cipher=$CIPHER,ecryptfs_key_bytes=$KEYLEN,ecryptfs_sig=$KEY1,ecryptfs_fnek_sig=$KEY2,ecryptfs_unlink_sigs,ecryptfs_passthrough=no,key=passphrase${@:+,$@}"
  if [ "$SRC" = "$DST" ]; then
    echo "ERROR: same source and destination directories."
    return 1
  fi
  chmod 700 "$SRC"
  ecryptfs-simple -o "$OPT" "$SRC" "$DST"
  chmod 770 "$DST"
}
umount_ecryptfs_simple() {
  local DST="${1:?Missing mounted directory...}"
  chmod 700 "$DST"
  ecryptfs-simple -uk "$DST"
}

############
# Private folder mount wrappers
mount_private_ecryptfs() {
  local SRC="${1:-$HOME/.private}"
  local DST="${2:-$HOME/private}"
  local SIG="${3:-$SRC/private.sig}"
  local KEY1="$(cat "$SIG" 2>/dev/null | head -n 1)"
  local KEY2="$(cat "$SIG" 2>/dev/null | tail -n 1)"
  local CONFNAME="${4:-$(basename "$DST")}"
  local TOOL="$5"
  if [ -z "$TOOL" ]; then
    command -v ecryptfs-simple >/dev/null && TOOL=mount_ecryptfs_simple || TOOL=mount_ecryptfs_root
  fi
  mkdir -p "$DST"
  "$TOOL" "$SRC" "$DST" "$KEY1" "$KEY2" "" "" "$CONFNAME"
}
umount_private_ecryptfs() {
  local DST="${1:-$HOME/private}"
  local TOOL="$2"
  if [ -z "$TOOL" ]; then
    command -v ecryptfs-simple >/dev/null && TOOL=umount_ecryptfs_simple || TOOL=umount_ecryptfs_root
  fi
  "$TOOL" "$DST"
}
setup_private_ecryptfs() {
  local SRC="${1:-$HOME/.private}"
  local DST="${2:-$HOME/private}"
  local SIG="${3:-$SRC/private.sig}"
  setup_ecryptfs "$SRC" "$DST" "$SIG"
}

#####################################
# Mount encfs
mount_encfs() {
  local SRC="${1:?Missing source directory...}"
  local DST="${2:?Missing dest directory...}"
  local KEY="${3:?Missing encfs key...}"
  local PASSFILE="${4}"
  shift $(($# < 4 ? $# : 4))
  ENCFS6_CONFIG="$(readlink -f "$KEY")" sudo -E encfs -o nonempty ${PASSFILE:+--extpass='cat "$PASSFILE"'} "$@" "$SRC" "$DST"
}
umount_encfs() {
  fusermount -u "${1:?Missing mounted directory...}"
}
mount_private_encfs() {
  local SRC="${1:-$HOME/.private}"
  local DST="${2:-$HOME/private}"
  mkdir -p "$DST"
  mount_encfs "$SRC" "$DST" "$KEY"
}
umount_private_encfs() {
  umount_encfs "${1:-$HOME/private}"
}

#####################################
# Mount dmcrypt using cryptsetup
# https://gist.github.com/d4v3y0rk/e19d346ec9836b4811d4fecc1e1d5d64
if command -v cryptsetup >/dev/null 2>&1; then
setup_dmcrypt() {
  local IMG="${1:?Missing image source file...}"
  local DST="${2:?Missing dest directory...}"
  local SIZE="${3:?Missing image file size (ex: 1024M)...}"
  local FTYPE="${4:-ext4}"
  local NAME="$(basename "$IMG" .img)"
  local MAP="/dev/mapper/$NAME"
  if [ -e "$IMG" ]; then
    echo "Error: image file $IMG exists already..."
    return 1
  fi
  if [ -e "$MAP" ]; then
    echo "Error: map device $MAP exists already..."
    return 1
  fi
  mkdir -p "$(dirname "$IMG")"
  fallocate -l "$SIZE" "$IMG"
  sudo cryptsetup -y luksFormat "$IMG"
  sudo cryptsetup open "$IMG" "$NAME"
  sudo mkfs.$FTYPE "$MAP"
}
mount_dmcrypt() {
  local IMG="${1:?Missing image source file...}"
  local DST="${2:?Missing dest directory...}"
  local SUDO_NOPASSWD="$3"
  local NAME="$(basename "$IMG" .img)"
  local MAP="/dev/mapper/$NAME"
  mkdir -p "$DST"
  if ! [ -e "$MAP" ]; then
    sudo cryptsetup open "$IMG" "$NAME"
  fi
  sudo mount "$MAP" "$DST"
  if [ -n "$SUDO_NOPASSWD" ]; then
    local USER="$(id -nu)"
    local GROUP="$(id -ng)"
    cat | sudo env EDITOR="tee" visudo -f "/etc/sudoers.d/cryptsetup-$NAME-$USER" <<EOF
$USER%$GROUP ALL=(root) NOPASSWD: $(command -v cryptsetup) open "$IMG" "$NAME"
$USER%$GROUP ALL=(root) NOPASSWD: $(command -v cryptsetup) close "$NAME"
$USER%$GROUP ALL=(root) NOPASSWD: $(command -v mount) "$MAP" "$DST"
$USER%$GROUP ALL=(root) NOPASSWD: $(command -v umount) "$DST"
EOF
  fi
}
umount_dmcrypt() {
  local IMG="${1:?Missing image source file...}"
  local DST="${2:?Missing dest directory...}"
  local NAME="$(basename "$IMG" .img)"
  sudo umount "$DST"
  sudo cryptsetup close "$NAME"
}
setup_private_dmcrypt() {
  local IMG="${1:-$HOME/.private/private.img}"
  local DST="${2:-$HOME/private}"
  local SIZE="${3:-4096M}"
  local FTYPE="${4:-ext4}"
  setup_dmcrypt "$IMG" "$DST" "$SIZE" "$FTYPE"
}
mount_private_dmcrypt() {
  local IMG="${1:-$HOME/.private/private.img}"
  local DST="${2:-$HOME/private}"
  mount_dmcrypt "$IMG" "$DST" "$3"
}
umount_private_dmcrypt() {
  local IMG="${1:-$HOME/.private/private.img}"
  local DST="${2:-$HOME/private}"
  umount_dmcrypt "$IMG" "$DST"
}
fi

#####################################
# Mount dmcrypt using cryptmount
# https://github.com/rwpenney/cryptmount
# https://www.enterprisenetworkingplanet.com/security/create-encrypted-volumes-with-cryptmount-and-linux/
# Basic setup: sudo cryptmount-setup
# Basic mount: cryptmount <name>
# Basic umount: cryptmount -u <name>
# Basic list: cryptmount -l
if command -v cryptmount >/dev/null 2>&1; then
setup_dmcrypt_cm() {
  local IMG="${1:?Missing image source file...}"
  local DST="${2:?Missing dest directory...}"
  local SIZE="${3:?Missing image file size (ex: 1024M)...}"
  local FTYPE="${4:-ext4}"
  local ALGO="${5:-aes-cbc-essiv}" #aes twofish
  local USER="${6:-$(id -un)}"
  local NAME="$(basename "$IMG" .img)"
  local MAP="/dev/disk/by-id/dm-name-$NAME"
  local KEY="${IMG}.key"
  if [ -e "$IMG" ]; then
    echo "Error: image file $IMG exists already..."
    return 1
  fi
  if [ -e "$KEY" ]; then
    echo "Error: keyfile $KEY exists already..."
    return 1
  fi
  if [ -e "$MAP" ]; then
    echo "Error: map device $MAP exists already..."
    return 1
  fi
  if cryptmount -l | grep "$NAME" >/dev/null; then
    echo "Error: image $NAME exists already..."
    return 1
  fi
  ( set -e
  mkdir -p "$(dirname "$IMG")"
  dd if=/dev/zero of="$IMG" bs="${SIZE}M" count=1
  mkdir -p "$DST"
  echo | sudo tee -a /etc/cryptmount/cmtab <<-EOF
$NAME {
    dev=$IMG
    dir=$DST
    fstype=$FTYPE
    mountoptions=defaults
    cipher=$ALGO
    keyformat=builtin
    keyfile=$KEY
}
EOF
  sudo cryptmount --generate-key 32 "$NAME"
  sudo cryptmount --prepare "$NAME"
  sleep 1
  sudo "mkfs.$FTYPE" "$MAP"
  sudo cryptmount --release "$NAME"  
  sudo chown "$USER:$USER" "$DST"
  sudo chmod 0700 "$DST"
  )
}
mount_dmcrypt_cm() {
  local IMG="${1:?Missing image source file...}"
  local NAME="$(basename "$IMG" .img)"
  cryptmount "$NAME"
}
umount_dmcrypt_cm() {
  local IMG="${1:?Missing image source file...}"
  local NAME="$(basename "$IMG" .img)"
  cryptmount -u "$NAME"
}
ls_dmcrypt_cm() {
  cryptmount -l
}
rm_dmcrypt_cm() {
  local IMG="${1:?Missing image source file...}"
  cryptmount -l "$IMG" || return $?
  sudo sed -i -r "/$IMG \{/,/\}/d" /etc/cryptmount/cmtab
}
setup_private_dmcrypt_cm() {
  local IMG="${1:-$HOME/.private/private.img}"
  local DST="${2:-$HOME/private}"
  local SIZE="${3:-4096M}"
  local FTYPE="${4:-ext4}"
  setup_dmcrypt_cm "$IMG" "$DST" "$SIZE" "$FTYPE"
}
mount_private_dmcrypt_cm() {
  local IMG="${1:-$HOME/.private/private.img}"
  local DST="${2:-$HOME/private}"
  local SIZE="${3:-4096M}"
  local FTYPE="${4:-ext4}"
  mount_dmcrypt_cm "$IMG" "$DST" "$SIZE" "$FTYPE"
}
umount_private_dmcrypt_cm() {
  local IMG="${1:-$HOME/.private/private.img}"
  umount_dmcrypt_cm "$IMG"
}
fi

#####################################
# Mount iso
mount_iso() {
  sudo mount -o loop -t iso9660 "$@"
}

# bin/cue to iso
conv_bin2iso() {
  local BIN="${1:?Missing BIN file...}"
  local CUE="${2:-${BIN%.*}.cue}"
  local ISO="${3:-${BIN%.*}.iso}"
  shift $(($# < 3 ? $# : 3))
  if [ ! -e "$CUE" ]; then
    # MODE1 is the track mode when it is a computer CD
    # MODE2 if it is a PlayStation CD.
    cat > "$CUE" <<EOF
FILE \"$BIN\" BINARY
TRACK 01 MODE1/2352
INDEX 01 00:00:00
EOF
  fi
  bchunk "$@" "$BIN" "$CUE" "$ISO"
}

# Mount dd img
mount_img() {
  local SRC="${1:?No image specified...}"
  local OFFSET="${2:?No byte offset specified. See fdisk -l '$SRC'}"
  local DST="${3:-/mnt}"
  sudo mkdir -p "$DST"
  sudo mount -o ro,loop,offset=$OFFSET "$SRC" "$DST"
}
umount_img() {
  local DST="${1:-/mnt}"
  sudo umount "$DST"
  [ "$(readlink -f "$DST")" != "/mnt" ] && sudo rmdir "$DST"
}

#####################################
# Unmount nfs
alias umountall_nfs='umount -a -t nfs'
umount_nfs() {
  local MOUNTPOINT="${1:?NFS mount point not specified...}"
  local ITF="${2:-eth0}"
  local IP="${3:-192.168.0.1}"
  local TMPFS="${4:-nfstmp}"
  #local TMPFS="${4:-fakenfs}"
  sudo sh -c "
    sh -c 'echo 0 > /proc/sys/kernel/hung_task_timeout_secs'
    ifconfig $ITF:$TMPFS $IP netmask 255.255.255.255
    umount -f -l \"$MOUNTPOINT\"
    ifconfig $ITF:$TMPFS down
  "
}

#####################################
# Toggle autofs
autofs_toggle() {
  sudo service autofs stop
  for MOUNT; do
    sudo umount -l "$MOUNT"
  done
  sleep 5s
  sudo service autofs start   
}

#####################################
# Check logged on users have a local home
nfs_who() {
  for LOGGED_USER in $(who | awk '{print $1}' | sort | uniq); do
    if [ -f /etc/exports ] && ! command grep -E "^[^#]*$LOGGED_USER" /etc/exports >/dev/null; then
      echo "WARNING: user $LOGGED_USER is logged in using a remote home..."
    fi
  done
}

# Give a user home server - if it is mounted locally
nfs_where() {
  for USER in ${@:-$(whoami)}; do
    mount | grep "$USER" | grep : | cut -d: -f 1
  done
}

#####################################
# Mount sshfs
alias umount_sshfs='fusermount -u'
alias mount_sshfs='sshfs -o cache=yes -o kernel_cache -o compression=no -o large_read'
alias mount_sshfs_fast='sshfs -o cache=yes -o kernel_cache -o compression=no -o large_read -o Ciphers=arcfour'

#####################################
# Mount & exec command
mount_exec() {
  local MOUNT="${1:?No mount specified...}"
  shift
  if mountpoint -q "$MOUNT"; then
    eval "$@"
  else
    trap "sudo umount -l '$MOUNT'" INT
    sudo mount "$MOUNT" &&
    eval "$@"
    sudo umount -l "$MOUNT"
    trap INT
  fi
}
