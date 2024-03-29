#!/bin/sh

################################
# Check fct exists
fct_exists() {
  true ${1:?No fct specified}
  #set | grep -G "^$1\s*()" >/dev/null 2>&1
  set | grep "^$1\s*()" >/dev/null 2>&1
  # The following code returns false when
  # function is overriden by an existing alias
  #[ "$(type -t $1)" = "function" ]
}

# Get fct definition
fct_def() {
  for FCT; do
    type "$FCT" 2>/dev/null | tail -n +2
  done
}

# Tiny fct definitions on oneline
fct_tiny() {
  fct_def "$@" | tr '\n' ';' | 
    sed -e 's/()\s*;/()/' -e 's/{\s*;/{/g' -e 's/;}/; }/g' -e 's/;;/;/g' -e 's/do\s*;/do/g' -e 's/then\s*;/then/g' -e 's/;$//'
    #sed -e 's/()\s*;/()/' -e 's/{\s*;/{/g' -e 's/{\s\+/{ /g' -e 's/\s\+}/ }/g' -e 's/;}/; }/g' -e 's/;;/;/g' -e 's/do\s*;/do/g' -e 's/then\s*;/then/g'
}

# Get fct content
fct_content() {
  for FCT; do
    type "$FCT" 2>/dev/null | head -n -1 | tail -n +4
  done
}

# Get alias content
alias_content() {
  for ALIAS; do
    #alias "$ALIAS" 2>/dev/null | awk -F= "{gsub(/'/,\"\"); print \$2}"
    type "$ALIAS" 2>/dev/null | awk -F '«.|.»' '/alias/{print $2}'
  done
}

# Define and call fct. Useful with xargs/do-while when functions are not exported in subshells
# ex: (set -vx; myfile() { for f in "$@"; do echo file="$# $f"; done; }; find . -type f -print0 | xargs -0 sh -c "$(fct_eval myfile \"\$@\")" _)
fct_eval() {
  local FCT="${1:?No fct specified}"; shift
  echo "$(fct_tiny "$FCT") ; $FCT" "$@"
}

# Run a function in sudo env
alias sudo_fct='fct_sudo'
fct_sudo() {
  local FCT="${1:?No fct defined...}"
  local CONTENT="$(fct_tiny $FCT)"; : ${CONTENT:?ERROR: cannot find fct $FCT...}
  shift
  sudo sh -c "$CONTENT; $FCT "'"$@"' _ "$@"
}
fct_sudo2() {
  local FCT1="${1:?No fct defined...}"
  local FCT2="${2:?No fct defined...}"
  local CONTENT1="$(fct_tiny $FCT1)"; : ${CONTENT1:?ERROR: cannot find fct $FCT1...}
  local CONTENT2="$(fct_tiny $FCT2)"; : ${CONTENT2:?ERROR: cannot find fct $FCT2...}
  shift 2
  sudo sh -c "$CONTENT1; $CONTENT2; $FCT2 "'"$@"' _ "$@"
}

# Append to fct
fct_append() {
  local FCT="${1:?No fct specified}"; shift
  eval "${FCT}() { $(fct_content $FCT); $@; }"
}

# Preppend to fct
fct_prepend() {
  local FCT="${1:?No fct specified}"; shift
  eval "${FCT}() { $@; $(fct_content $FCT); }"
}

# Check alias/fct collision
fct_collision() {
  for ALIAS in $(alias | awk -F '[= ]' '{print $2}'); do
    [ "${1:-$ALIAS}" = "$ALIAS" ] &&
    fct_exists "$ALIAS" && 
    echo "$ALIAS"
  done
}

# Wrap script fcts in aliases
# Useful ?
fct_wrap() {
  for SCRIPT; do
    SCRIPT="$(readlink -f "$SCRIPT")"
    while IFS= read -r FCT; do 
      alias $FCT="(unalias -a; . $SCRIPT; eval $FCT)"
    done <<EOF
$(awk -F '(' '/^.*_.*\s*\(\)\s*\{?$/ {print $1}' "$SCRIPT")
EOF
  done
}
