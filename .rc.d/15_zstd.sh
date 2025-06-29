#!/bin/sh

###############################
# Quick zstd compress/deflate
zstdq() {
  for SRC; do
    if [ "$SRC" != "${SRC%.zst}" ]; then
      zstdd "." "$SRC"
    else
      zstda "${SRC%/}.zst" "$SRC"
    fi
  done
}

# zstd compress
zstda() {
  local ARCHIVE="${1:?No archive to create...}"
  shift 1
  command zstd -z "$@" -o "$ARCHIVE"
}

# zstd deflate
zstdd() {
  local DST="${1:?No output directory specified...}"
  local SRC
  shift 1
  mkdir -p "$DST"
  for SRC; do
    command zstd -d "$SRC" -o "$DST/$(basename "$SRC" .zst)"
  done
}

########################################
########################################
# Last commands in file
# Execute function from command line
[ "${1#zstd}" != "$1" ] && "$@" || true
