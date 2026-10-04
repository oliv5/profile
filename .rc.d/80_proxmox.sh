#!/bin/sh

# SCP to proxmox containers
lxc_push() {
  local SRC="$1" SRV="$2" LXC_ID="$3" DST="$4"
  : ${1:?No source file specified...}
  : ${2:?No proxmox server specified...}
  : ${3:?No LXC ID specified...}
  : ${4:?No destination file specified...}
  local NAME="$(basename "$SRC")"
  local TMP="$(ssh "$SRV" mktemp -d /tmp/ct-upload-XXXX)"
  echo "Using temporary folder $SRV:$TMP"
  if [ "${TMP#/tmp/*}" = "$TMP" ]; then
    echo >&2 "Error: \$TMP does not start with /tmp"
    return 1
  fi

  scp -r "$SRC" "$SRV:$TMP"

  if [ -d "$SRC" ]; then
    ssh -t "$SRV" "
      set -e; trap 'rm -rf \"$TMP\"' EXIT INT TERM HUP
      cd \"$TMP/$NAME\"
      echo 'Creating subfolders...'
      find . -mindepth 1 -type d | while read dir; do
        rel=\"\${dir#./}\"
        sudo pct exec \"$LXC_ID\" -- mkdir -p \"$DST/\$rel\"
      done
      echo 'Pushing files...'
      find . -type f | while read file; do
        rel=\"\${file#./}\"
        sudo pct push \"$LXC_ID\" \"\$file\" \"$DST/\$rel\"
      done
    "
  else
    ssh -t "$SRV" "
      trap 'rm -rf \"$TMP\"' EXIT INT TERM HUP
      sudo pct push \"$LXC_ID\" \"$TMP/$NAME\" \"$DST\"
    "
  fi
}

lxc_pull() {
  local SRC="$1" SRV="$2" LXC_ID="$3" DST="$4"
  : ${1:?No source file specified...}
  : ${2:?No proxmox server specified...}
  : ${3:?No LXC ID specified...}
  : ${4:?No destination file specified...}
  local NAME="$(basename "$SRC")"
  local TMP="$(ssh "$SRV" mktemp -d /tmp/ct-download-XXXX)"
  echo "Using temporary folder $SRV:$TMP"
  if [ "${TMP#/tmp/*}" = "$TMP" ]; then
    echo >&2 "Error: \$TMP does not start with /tmp"
    return 1
  fi

  if ssh -t "$SRV" "sudo pct exec \"$LXC_ID\" -- test -d \"$SRC\"" 2>/dev/null; then
    ssh -t "$SRV" "
      set -e; trap 'rm -rf \"$TMP\"' EXIT INT TERM HUP
      mkdir -p \"$TMP/$NAME\"
      echo 'Pulling files...'
      sudo pct exec \"$LXC_ID\" -- find \"$SRC\" -type d | while read dir; do
        rel=\"\${dir#$SRC}\"
        mkdir -p \"$TMP/$NAME\$rel\"
      done
      sudo pct exec \"$LXC_ID\" -- find \"$SRC\" -type f | while read file; do
        rel=\"\${file#$SRC}\"
        sudo pct pull \"$LXC_ID\" \"\$file\" \"$TMP/$NAME\$rel\"
      done
    "
  else
    ssh -t "$SRV" "
      set -e; trap 'rm -rf \"$TMP\"' EXIT INT TERM HUP
      sudo pct pull \"$LXC_ID\" \"$SRC\" \"$TMP/$NAME\"
    "
  fi

  scp -r "$SRV:$TMP/$NAME" "$DST"
  ssh "$SRV" "rm -rf \"$TMP\""
}

lxc_exec() {
  local SRV="$1" LXC_ID="$2"
  : ${1:?No proxmox server specified...}
  : ${2:?No LXC ID specified...}
  : ${3:?No command specified...}
  shift 2

  ssh -t "$SRV" "sudo pct exec \"$LXC_ID\" -- $@"
}
