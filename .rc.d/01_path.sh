#!/bin/sh

# Some general-purpose fcts
command -v relpath >/dev/null ||
relpath() {
  { command -v realpath >/dev/null && realpath -m --relative-to="${2:-$PWD}" "$1"; } ||
  { command -v python >/dev/null && python -c "import os.path; print(os.path.relpath('$1', '${2:-$PWD}'))"; } ||
  echo "$1"
}
command -v abspath >/dev/null ||
abspath() {
  { command -v realpath && realpath -m "$1"; } ||
  { command -v readlink && readlink -f -- "$1"; } ||
  { command -v python && python -c "import os.path; print(os.path.abspath('$1'))"; } ||
  echo "$1"
}

# Timeout wrapper
command -v timeout >/dev/null &&
_path_timeout() { timeout 0.5s "$@"; } ||
_path_timeout() { "$@"; }

# Prepend to path
_path_prepend() {
  local VAR="${1:-PATH}"
  shift
  local DIR
  local RES=""
  for DIR; do
    if _path_timeout [ -d "$DIR" ]; then
      RES="${RES:+$RES:}${DIR}"
    fi
  done
  eval export $VAR="${RES:+$RES:}\${$VAR}"
}

# Append to path
_path_append() {
  local VAR="${1:-PATH}"
  shift
  local DIR
  local RES=""
  for DIR; do
    if _path_timeout [ -d "$DIR" ]; then
      RES="${RES:+$RES:}${DIR}"
    fi
  done
  eval export $VAR="\${$VAR}${RES:+:$RES}"
}

# Remove from path
_path_remove() {
  command -v sed >/dev/null || return 1
  local VAR="${1:-PATH}"
  shift
  local DIR
  eval local RES="\$$VAR"
  for DIR; do
    RES="$(echo $RES | sed -r "s;${DIR}:?;;g ; s/^:// ; s/:$//")"
  done
  eval export $VAR="$RES"
}

# Remove given fs from path, as well as absent paths
_path_remove_fs() {
  command -v grep >/dev/null || return 1
  command -v stat >/dev/null || return 1
  local VAR="${1:-PATH}"
  local VAL="$(eval echo "\$$VAR")"
  local FS="${2:-cifs|fusefs|nfs}"
  local IFS=":"
  local RES=""
  for D in $VAL; do
    local CURFS="$(timeout 1s stat -f -c %T "$D" 2>/dev/null)"
    if [ $? -ne 0 ] || ! echo "$CURFS" | grep -Eq "$FS"; then
      RES="${RES:+$RES:}$D"
    fi
  done
  export $VAR="$RES"
}

# Remove absent path
_path_remove_absent() {
  local VAR="${1:-PATH}"
  local VAL="$(eval echo "\$$VAR")"
  local IFS=":"
  local RES=""
  for D in $VAL; do
    _path_timeout [ -d "$D" ] && RES="${RES:+$RES:}$D"
  done
  export $VAR="$RES"
}

# Cleanup path: remove duplicated or empty entries, expand $HOME
_path_cleanup() {
  command -v awk >/dev/null || return 1
  command -v sed >/dev/null || return 1
  command -v cat >/dev/null || return 1
  local VAR="${1:-PATH}"
  shift
  eval trap "\"export $VAR='\${$VAR}'; trap - EXIT\"" EXIT
  export $VAR="$(
    eval echo "\$$VAR" |
    sed -r 's|\"||g' |
    { awk -vRS=: -vORS=: '!seen[$0]++ {str=str$1ORS} END{sub(ORS"$", "", str); printf "%s\n",str}' || cat; } |
    { awk 'NF && !x[$0]++' RS='[:|\n]' ORS=':' || cat; } |
    sed -r 's|~|'"${HOME}"'|g; s|\:\.||g; s|(^:\|:$)||')"
  trap - EXIT
}

# Find and append path
_path_find() {
  command -v find >/dev/null || return 1
  local VAR="${1:-PATH}"
  local DIR="${2:-.}"
  local NAME="${3}"
  local RES="$(find "$DIR" ${NAME:+-name "$NAME"} -type d -print0 | xargs -r0 printf '%s')"
  export $VAR="$(eval echo "\$$VAR")${RES:+:$RES}"
}

# PATH aliases
path_prepend() { _path_prepend PATH "$@"; }
path_append() { _path_append PATH "$@"; }
path_remove() { _path_remove PATH "$@"; }
path_remove_fs() { _path_remove_fs PATH "$@"; }
path_remove_absent() { _path_remove_absent PATH "$@"; }
path_cleanup() { _path_cleanup PATH "$@"; }
path_find() { _path_find PATH "$@"; }
path_reset() { export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"; }

# LD_LIBRARY_PATH aliases
# Warning: we should not use LD_LIBRARY_PATH
# see https://tldp.org/HOWTO/Program-Library-HOWTO/shared-libraries.html
# see ftp://linuxmafia.com/faq/Admin/ld-lib-path.html
# see http://www.visi.com/~barr/ldpath.html
ldlibpath_prepend() { _path_prepend LD_LIBRARY_PATH "$@"; }
ldlibpath_append() { _path_append LD_LIBRARY_PATH "$@"; }
ldlibpath_remove() { _path_remove LD_LIBRARY_PATH "$@"; }
ldlibpath_remove_fs() { _path_remove_fs LD_LIBRARY_PATH "$@"; }
ldlibpath_remove_absent() { _path_remove_absent LD_LIBRARY_PATH "$@"; }
ldlibpath_cleanup() { _path_cleanup LD_LIBRARY_PATH "$@"; }
ldlibpath_find() { _path_find LD_LIBRARY_PATH "$@"; }
ldlibpath_reset() { unset LD_LIBRARY_PATH; }

# Cleanup environement from some dangerous lib hijacking technics
# See https://repo.zenk-security.com/Techniques%20d.attaques%20%20.%20%20Failles/Quelques%20astuces%20avec%20LD_PRELOAD.pdf
ld_cleanup() { unset LD_LIBRARY_PATH LD_PRELOAD LD_DEBUG; }

# Load common variables to make what is called a prefix.
prefix_load() {
  local REPLY="$(readlink -f "$1")"
  #realpath.absolute "$1"
  _path_append MANPATH "$REPLY/man"
  _path_append MANPATH "$REPLY/share/man"
  _path_append CPATH "$REPLY/include"
  _path_append LD_LIBRARY_PATH "$REPLY/lib"
  _path_append LIBRARY_PATH "$REPLY/lib"
  _path_append PATH "$REPLY/bin"
  _path_append PKG_CONFIG_PATH "$REPLY/lib/pkgconfig"
}

