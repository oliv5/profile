#!/bin/sh

# Quick gzip compress/deflate
gz() {
  for SRC; do
    if [ "$SRC" != "${SRC%.gz}" ]; then
      gzd "." "$SRC"
    else
      gza "${SRC%/}.gz" "$SRC"
    fi
  done
}

# gzip add
gza() {
  local ARCHIVE="${1:?No archive to create...}"
  shift 1
  gzip -rk9 "$@" > "$ARCHIVE" &&
    echo "$ARCHIVE"
}

# gzip deflate
gzd() {
  local DST="${1:?No output directory specified...}"
  local SRC
  shift 1
  (cd "$DST" &&
    for SRC; do
      gunzip -dk "$SRC"
    done
  )
}

# gzip test archive
gzt() {
  local RES=0
  local SRC
  for SRC; do
    gzip -tq "$SRC" || RES=$?
  done
  return $RES
}

###############################
# Quick gzip > gpg compress/deflate
gzg() {
  local KEY="${1:?No encryption key specified...}"
  shift
  for SRC; do
    if [ "$SRC" != "${SRC%.gz.gpg}" ]; then
      gzgd "." "$SRC"
    else
      gzga "$KEY" "${SRC%/}.gz.gpg" "$SRC"
    fi
  done
}

# gzip > gpg compress
gzga(){
  local KEY="${1:?No encryption key specified...}"
  local ARCHIVE="${2:?No archive to create...}"
  shift 2
  zip -r9 - "$@" | gpg --encrypt --recipient "$KEY" > "$ARCHIVE" &&
    echo "$ARCHIVE"
}

# gpg > gzip > tar deflate
gzgd(){
  local DST="${1:?No output directory specified...}"
  local SRC
  shift 1
  mkdir -p "$DST"
  for SRC; do
    gpg --decrypt --batch "$SRC" | funzip > "$DST/$(basename "${SRC%.gz.gpg}")"
  done
}

###############################
# Unit test
#~ _unittest gz 'gzg 0x95C1629C87884760'

########################################
########################################
# Last commands in file
# Execute function from command line
[ "${1#gz}" != "$1" ] && "$@" || true
