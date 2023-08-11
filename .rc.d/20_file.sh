#!/bin/sh

#####
# Set default file access rights
#
# https://www.linuxquestions.org/questions/linux-desktop-74/applying-default-permissions-for-newly-created-files-within-a-specific-folder-605129/
#
# umask: umask 0022 /folder (0022 is removed from 666 or 777)
# GID: chmod g+s /folder
# ACL: setfacl -d -m g::rwx /folder

################################
# File size
alias fsize='stat -L -c %s'

# File name/extension
fext(){
  for F; do echo "${F##*.}"; done
}
fname(){
  for F; do echo "${F%.*}"; done
}

################################
# Recursive permisions/owner
alias chown_r='chown -R'
chmod_r() {
  local DIR="${1:-./}"
  local PERMS_DIR="${2:-0750}"
  local PERMS_FILES="${2:-0640}"
  find "$DIR" -type d -exec chmod "$PERMS_DIR" '{}' + -o -type f -exec chmod "$PERMS_DIR" '{}' +
}

################################
# http://unix.stackexchange.com/questions/59112/preserve-directory-structure-when-moving-files-using-find
# Move by replicating directory structure
# See also rsync_mktree
mkdir_mv() {
  local SRC="$1"
  local DST="$(path_abs "${2:-.}")"
  shift 2
  local BASENAME="$(basename "$SRC")"
  find "$(dirname "$SRC")" -name "${BASENAME:-*}" $@ -exec sh -c '
      for x; do
        mkdir -p "$0/${x%/*}" &&
        mv "$x" "$0/$x"
      done
    ' "$DST" {} +
}

################################
# Rsync
alias rsync_cp='rsync -a' # Recursive copy
alias rsync_mv='rsync -a --remove-source-files' # Recursive move
alias rsync_mktree='rsync -a -f"+ */" -f"- *"'  # Replicate tree
alias rsync_cptree='rsync -R' # Copy & keep relative tree
alias rsync_mvtree='rsync -R --remove-source-files' # Move & keep relative tree
alias rsync_timestamp='rsync -rt --size-only --existing' # Update timestamps only
alias rsync_cpn='rsync -a --ignore-existing' # Recursive copy, new files only
alias rsync_mvn='rsync -a --remove-source-files --ignore-existing' # Recursive move, new files only
alias rsync_cpu='rsync -a --existing' # Recursive copy, existing files only
alias rsync_mvu='rsync -a --remove-source-files --existing' # Recursive move, existing files only

# https://askubuntu.com/questions/719439/using-rsync-with-sudo-on-the-destination-machine
# in sudoers: $USER ALL=(ALL) NOPASSWD:/usr/bin/rsync
rsync_as_user() {
  rsync --rsync-path="sudo /usr/bin/rsync" "$@"
  #~ read -s -p "Remote sudo password: " SUDOPASS && rsync --rsync-path="echo $SUDOPASS | sudo -Sv && sudo rsync" "$@"
}

##############################
# Copy files & preserve permissions
alias cp_rsync='rsync_cp'
cp_tar() {
  tar cvfp - "${1:?No source specified...}" | ( cd "${2:?No destination specified...}/" ; tar xvfp - )
}
cp_cpio() {
  find "${1:?No source directory specified...}/" -print -depth | cpio -pdm "${2:?No destination directory specified...}/"
}
ssh_cpout() {
  find "${1:?No local source directory specified...}/" -depth -print | cpio -oaV | ssh "${2:?No remote destination user@host:port/directory specified...}/" 'cpio -imVd'
}
ssh_cpin() {
  ssh "${1:?No remote source user@host:port/directory specified...}/" "find \"${2:?No local destination directory specified...}/\" -depth -print | cpio -oaV" | cpio -imVd
}

##############################
# Duplicate element with incremental num
bak() {
  for ELEM; do
    cp -rv "${ELEM%/}" "${ELEM%/}.$(ls -d1 "${ELEM%/}".* 2>/dev/null | wc -l)"
  done
}

# Move element with incremental num
bak_mv() {
  for ELEM; do
    mv -v "${ELEM%/}" "${ELEM%/}.$(ls -d1 "${ELEM%/}".* 2>/dev/null | wc -l)"
  done
}

# Duplicate element with date
bak_date() {
  local DATE="$(date +%Y%m%d-%H%M%S)"
  for ELEM; do
    cp -rv "${ELEM%/}" "${ELEM%/}.${DATE}.bak"
  done
}

# Move element with date
bak_date_mv() {
  local DATE="$(date +%Y%m%d-%H%M%S)"
  for ELEM; do
    mv -v "${ELEM%/}" "${ELEM%/}.${DATE}.bak"
  done
}

##############################
# Replace symlink by the actual file
# Not equal to the "unlink" legacy tool
file_unlink() {
  for FILE; do
    LINK="$(readlink "$FILE")"
    [ -n "$LINK" ] && cp --remove-destination "$LINK" "$FILE"
  done
}

##############################
# Swap files or directories
swap() {
  local FILE1="${1:?Nothing to swap...}"
  local FILE2="${2:?Nothing to swap...}"
  local TMP=""; [ -d "$FILE2" ] && TMP="-d"
  TMP="$(mktemp --tmpdir="$PWD" $TMP)"
  mv -fT "$FILE2" "$TMP"
  mv -fT "$FILE1" "$FILE2"
  mv -fT "$TMP" "$FILE1"
}

################################
# http://unix.stackexchange.com/questions/59112/preserve-directory-structure-when-moving-files-using-find
# Move by replicating directory structure
mkdir_mv() {
  local SRC="$1"
  local DST="$(path_abs "${2:-.}")"
  shift 2
  local BASENAME="$(basename "$SRC")"
  find "$(dirname "$SRC")" -name "${BASENAME:-*}" $@ -exec sh -c '
      for x; do
        mkdir -p "$0/${x%/*}" &&
        mv "$x" "$0/$x"
      done
    ' "$DST" {} +
}

################################
# Move files from multiple sources while filtering extensions
# ex: EXCLUDE="temp *.bak" move $DST/ $SRC1/ $SRC2/
move() {
  local DST="${1?No destination specified...}"; shift
  local OPT=""; for EXT in $EXCLUDE; do OPT="${OPT:+$OPT }--exclude=$EXT"; done
  for SRC; do
    rsync -av --progress --remove-source-files --prune-empty-dirs $OPT "$SRC/" "$DST/" 2>/dev/null
  done
}

# Move files from mounted drives
move_mnt() {
  local MNT="${1?No mountpoint specified...}"; shift
  sudo mount "$MNT" &&
    move "$@"
}

################################
alias check_md5='check_hash md5sum'
alias check_sha1='check_hash sha1sum'
alias check_sha256='check_hash sha256sum'
check_hash() {
  local CMD="${1:?No hash cmd specified}"
  shift
  while [ $# -gt 1 ]; do
    local FILE="$1"
    local HASH1="$2"
    eval local HASH2="\$($CMD '$FILE' | cut -d ' ' -f 1)"
    [ "$HASH1" = "$HASH2" ] || { echo "$FILE"; return 1; }
    shift 2
  done
  return 0
}

################################
if ! command -v rename >/dev/null; then
  rename() {
    find "${4:-.}" -name "${1:?No file specified...}" -execdir \
      sh -c 'REP="$1"; shift; for F; do mv -vi "$F" "$(echo $F | sed -e "$REP")"; done' _ "${2:?No sed replace pattern specified...}" {} \;
  }
fi

################################
# Find garbage files
ff_garbage() {
  printf "Home garbage\n"
  find "$HOME" -type f -name "*~" -print
  printf "\nSystem coredumps\n"
  sudo find /var -type f -name "core" -print
  printf "\nTemporary files\n"
  sudo ls /tmp
  sudo ls /var/tmp
  printf "\nLogs\n"
  sudo du -a -b /var/log | sort -n -r | head -n 10
  sudo ls /var/log/*.gz
  printf "\nOpened but deleted\n"
  sudo lsof -nP | grep '(deleted)'
  sudo lsof -nP | awk '/deleted/ { sum+=$8 } END { print sum }'
  sudo lsof -nP | grep '(deleted)' | awk '{ print $2 }' | sort | uniq
}
