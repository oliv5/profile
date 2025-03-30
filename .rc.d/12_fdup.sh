#!/bin/sh

###########################################
# Find duplicate files in directory (by content)
alias ff_dup0='find_duplicates0'
alias ff_dup='find_duplicates'
find_duplicates0() {
  local TMP1="$(mktemp)"
  local TMP2="$(mktemp)"
  local FILETYPES="${FILETYPES:--o -type l}"
  echo -n > "$TMP1"
  for DIR in "${@:-.}"; do
    find "${DIR:-.}" \( -type f $FILETYPES \) -exec md5sum -z "{}" \; >> "$TMP1"
  done
  sort -z -k 1 "$TMP1" | cut -z -d' ' -f 1 | uniq -z -d | xargs -r0 > "$TMP2"
  while read SUM; do
    printf "$SUM\0"
    grep -zZ "$SUM" "$TMP1" | cut -z -d$' ' -f 3-
  done < "$TMP2"
  rm "$TMP1" "$TMP2" 2>/dev/null
}
find_duplicates() {
  find_duplicates0 "$@" | xargs -r0 -n1
}

# Remove duplicated files (by content)
# Does not handle filenames with \n inside
# Dry-run only, does not execute the rm command
alias rm_dup0='rm_duplicates0'
alias rm_dup='rm_duplicates'
rm_duplicates0() {
  find_duplicates0 "$@" | xargs -r0 sh -c '
    while [ $# -gt 0 ]; do
      F="$1"; shift
      if [ ! -e "$F" ] && [ ${#F} -eq 32 ]; then
        shift # Skip next file
      elif [ -e "$F" ]; then
        printf "$F\0"
      fi
    done
  ' _ | xargs -r0 -- echo rm -I --
}
rm_duplicates() {
  rm_duplicates0 "$@" | xargs -r0 -n1
}

# Find duplicate links of all links (good/bad)
ffl_dup() {
  for D in "${@:-.}"; do
    find "$D" -type l -exec sh -c '
	    find "$2" -lname "*$(basename "$(readlink -q "$1")")" -print0 | sort -z | xargs -r0 -- sh -c "[ \$# -ge 1 ] && echo \$0 \$@"
    ' _ {} "$D" \; | sort -u
  done
}
# Find duplicate links (raw list)
ffl_dupr() {
  for D in "${@:-.}"; do
    find "$D" -type l -exec sh -c '
	    find "$2" -lname "*$(basename "$(readlink -q "$1")")" -print0 | sort -z | xargs -r0 -- sh -c "[ \$# -ge 1 ] && echo \$0 && for F; do echo "\$F"; done"
    ' _ {} "$D" \; | sort -u
  done
}

# Find duplicate links of good links
ffl_dupg() {
  for D in "${@:-.}"; do
    find "$D" -type f -exec sh -c '
	    #find -L "$2" -samefile "$1" -xtype l -print0 | xargs -r0
      find "$2" -lname "$(basename "$1")" -print0 | xargs -r0
    ' _ {} "$D" \;
  done
}

###########################################
# Find duplicate files in directory (by name)
alias ff_dupn0='find_duplicate_names0'
alias ff_dupn='find_duplicate_names'
find_duplicate_names0() {
  {
    local D
    for D in "${@:-.}"; do
      find "$D" ! -type d -print0
    done
  } | awk -F'/' '
  BEGIN {
    RS = "\0" 
  } {
    f = $NF
    a[f] = f in a? a[f] RS $0 : $0
    b[f]++
  } END {
    for(f in b)
      if(b[f]>1)
        printf "%s\0",a[f]
  }'
}
find_duplicate_names() {
  find_duplicate_names0 "$@" | xargs -r0 -n1
}
