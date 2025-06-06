#!/bin/sh
# For reference: bash madness https://unix.stackexchange.com/questions/210158/how-can-i-list-bashs-options-for-the-current-shell#210161

# Quote all shell parameters
arg_quote() {
  local ARG
  for ARG; do
    SQESC=$(printf '%s\n' "${ARG}" | sed -e "s/'/'\\\\''/g")
    printf '%s ' "'${SQESC}'"
  done
}
arg_dblquote() {
  local ARG
  for ARG; do
    SQESC=$(printf '%s\n' "${ARG}" | sed -e 's/"/\\"/g')
    printf '%s ' '"'${SQESC}'"'
  done
}
# Quote all shell parameters.
# Unsafe: does not escape inner quotes
arg_quote_unsafe() {
  printf "'%s' " "$@"
}
arg_dblquote_unsafe() {
  printf '"%s" ' "$@"
}

# Left/right trim shell parameters. Adds quotes
arg_rtrim() {
  local ARG
  for ARG in $(seq 2 $(($#-$1))); do 
    eval SQESC="\${$ARG}"
    SQESC=$(printf '%s\n' "${SQESC}" | sed -e "s/'/'\\\\''/g")
    printf '%s ' "'${SQESC}'"
  done
}
arg_ltrim() {
  command shift ${1:-1} >/dev/null 2>&1
  arg_quote "$@"
}

# Right shift parameters "a.k.a remove last parameters". Does not add quotes.
alias rshift='arg_rshift'
arg_rshift() {
  eval set -- $(arg_rtrim 1 "$@")
}

# Concat parameters separated by a fixed delimiter
arg_join() {
  local DELIM="${1:?No delimiter defined...}"
  shift
  local ARG
  for ARG; do
    printf '%s %s ' "$DELIM" "$ARG"
  done
}

# Get last in list
arg_last() {
  [ $# -gt 0 ] && command shift $(($#-1)) && echo "$1"
}
arg_lastn() {
  [ $# -gt 1 ] && command shift $(($#-$1)) && echo "$1"
}

# Is in list?
alias is_in='arg_is_in'
arg_is_in() {
  [ $# -lt 2 ] && return 1
  local Q="$1"
  shift
  local A
  for A; do [ "$A" = "$Q" ] && return 0; done
  return 1
}

# Save & restore shell parameters
arg_save_var() { local _VAR_="${1:-__}"; [ $# -ge 1 ] && shift; local _VAL_="$(arg_quote "$@")"; eval "$_VAR_=\"$_VAL_\""; }
alias arg_save='__="$(arg_quote "$@")"'
alias arg_reset='arg_save; set --'
alias arg_restore='eval set -- "$__"'

# Intersect 2 arguments lists
arg_intersect() {
  local L1="${1:?No list #1 specified...}"
  local L2="${2:?No list #2 specified...}"
  { local A; for A; do echo $A; done; } | sort -u
}

# Show differences between 2 arguments lists
arg_diff() {
  local L1="${1:?No list #1 specified...}"
  local L2="${2:?No list #2 specified...}"
  { local A; for A; do echo $A; done; } | sort | uniq -d
}

################################
# https://stackoverflow.com/questions/18186929/differences-between-login-shell-and-interactive-shell
# http://www.tldp.org/LDP/abs/html/intandnonint.html

# Replace with a fresh shell; keeps current env variables
shell_replace() {
  exec "${1:-$0}" -li
}

# Reload the shell entirely; lose env variables
shell_reload() {
  if [ -n "$BASH_VERSION" ]; then
    exec env -i bash -li
  else
    exec env -i HOME="$HOME" ENV="$HOME/.rc" $0 -li
  fi
}

# Returns true for interactive shells
# Oneliner: shell_isinteractive() { case $- in *i*) return 0;; *) [ -t "0" ] || ! [ -p /dev/stdin ];; esac; }
shell_isinteractive() {
  case $- in
    *i*) return 0;; # for bash
    #*) return 1;; # for bash-only [not working?]
    *) [ -t "0" ] || ! [ -p /dev/stdin ] # not bash: test whether stdin exists
  esac
}

# Returns true for login shells
shell_islogin() {
  # Test whether the caller name starts with a "-"
  [ "$(echo "$0" | cut -c 1)" = "-" ]
}

# Few shift aliases to prevent fatal error 
# and eat all arguments when over-shifting
# Other method: shift 2>/dev/null || set --
# Other method: shift $(min $# number)
# Other method: [ $# -ge number ] && shift number || shift $#
alias shift1='command shift 1 2>/dev/null'
alias shift2='command shift 2 2>/dev/null || set --'
alias shift3='command shift 3 2>/dev/null || set --'
alias shift4='command shift 4 2>/dev/null || set --'
alias shift5='command shift 5 2>/dev/null || set --'
alias shift6='command shift 6 2>/dev/null || set --'
alias shift7='command shift 7 2>/dev/null || set --'
alias shift8='command shift 8 2>/dev/null || set --'
alias shift9='command shift 9 2>/dev/null || set --'

# Get script path
shell_script() {
  if [ -n "$BASH_VERSION" ]; then echo "${BASH_SOURCE[0]}"; else
  if [ "$OSTYPE" = *darwin* ]; then greadlink -f "$0"; else readlink -f "$0"; fi; fi
}
shell_path() {
  # if [ -n "$BASH_VERSION" ]; then (builtin cd "$(dirname "${BASH_SOURCE[0]}")" && pwd); else
  if [ -n "$BASH_VERSION" ]; then readlink -f "$(dirname "${BASH_SOURCE[0]}")"
  elif [ "$OSTYPE" = *darwin* ]; then greadlink -f "$(dirname "$0")"
  else readlink -f "$(dirname "$0")"; fi
}

# Open shell with no ASLR. Set ADDR_NO_RANDOMIZE personality (man sys/personality.h) to all children.
# Same as echo 0 | tee /proc/sys/kernel/randomize_va_space (0=no ASLR, 1=only shared lib, 2=global)
shell_noaslr() {
  setarch "$(uname -m)" -R "$SHELL"
}

# Swap IFS temporarily
shell_ifs() {
  local IFS="${1:?No IFS specified...}"
  shift
  $@ # execute in current environment. No quotes, or IFS is not applied.
}

################################
# Die function
die() {
  local ERRCODE="${1:-1}"
  shift
  printf "$@"
  shell_isinteractive && {
    echo "Die cannot exit the main shell. Press ctrl-c to stop."
    read
    return $ERRCODE
  } || exit $ERRCODE;
}

# Set error code
error() { return ${1:-0}; }
err() { return ${1:-0}; }

################################
# Directory management
dir_empty() {
  test -z "$(find "$1" -mindepth 1 -printf X -quit)"
}

################################
# Remove a string from variable
var_remove() {
  local VAR="${1:?No variable name defined...}"
  shift
  for PAT; do
    if [ "$(eval echo \${$VAR##*$PAT})" != "$(eval echo \$${VAR})" ]; then
      eval "$VAR=\${${VAR}%%$PAT*}\${${VAR}##*$PAT}"
    fi
  done
}

# Is pattern in string
var_has() {
  local VAR="${1:?No variable name defined...}"
  shift
  for PAT; do
    [ "$(eval echo \${$VAR##*$PAT})" == "$(eval echo \$${VAR})" ] && return 1
  done
  return 0
}

################################
# Get error status of piped commands:
# option #1: bash set -o pipefail and ${PIPESTATUS[0]}
# option #2: use mispipe (sudo apt install moreutils)
# option #3: use named pipes to do an alternate mispipe implementation

# Create a named fifo/pipe
crpipe() {
  local PIPE="${1:-$(mktemp -u)}"
  if [ -p "$PIPE" ]; then
    echo "$PIPE"
  else
    mkfifo -m 600 "$PIPE" &&
      echo "$PIPE"
  fi
}

# Wait data from pipe and discard it
wtpipe() {
  cat >/dev/null <"$1"
}

# Create unamed pipes linked to a local stream (not stdin/stdout/stderr)
# Input is a stream number > 2
mkpipe() {
  local P
  for P; do
    # Create a temporary named pipe/fifo
    local FIFO="$(mktemp -u)"
    mkfifo -m 600 "$FIFO"
    # Attach to file descriptor in rw mode "<>"
    eval "exec $P<>\"$FIFO\""
    # Unlink the named pipe/fifo
    rm "$FIFO"
  done
}

# Close unamed pipes
rmpipe() {
  local P
  for P; do
    eval "exec $P>&-"
  done
}

# Pipe multiple writers into a single reader
# Same as bash process substitution
# "reader <(writer1) <(writer2)"
wrpipe() {
  local READER="${1:?Reader command not specified...}"
  shift
  local DIR="$(mktemp -d)"
  local W
  for W in $(seq $#); do
    mkfifo -m 600 "$DIR/$W"
  done
  for W in $(seq $#); do
    eval "$1" > "$DIR/$W" &
    shift
  done
  eval "$READER" "$DIR"/*
  rm -r "$DIR"
}
# Pipe a single writer into multiple readers
rdpipe() {
  local WRITER="${1:?Writer command not specified...}"
  shift
  local DIR="$(mktemp -d)"
  local R
  for R in $(seq $#); do
    mkfifo -m 600 "$DIR/$R"
  done
  for R in $(seq $#); do
    eval "$1" < "$DIR/$R" &
    shift
  done
  eval "$WRITER" | tee "$DIR"/* >/dev/null
  rm -r "$DIR"
}

# Custom mispipe using redirects
# Executes 2 cmds in a pipe & returns the status of the first one
# https://unix.stackexchange.com/a/16709
# https://linux.die.net/man/1/mispipe
# https://unix.stackexchange.com/questions/14270/get-exit-status-of-process-thats-piped-to-another
command -v mispipe >/dev/null 2>&1 ||
mispipe() {
  # Ex: ( exec 4>&1 5>&2; ERR=$({ { (echo 'toto titi'; false); echo $? >&3; } | grep toto; } 3>&1 >&4 2>&5); exec 4>&- 5>&-; echo "Errcode=$ERR" )
  # Ex: { { { { someprog; echo $? >&3; } | filter >&4; } 3>&1; } | { read xs; exit $xs; } } 4>&1
  local CMD1="${1:?No command 1 specified...}"
  local CMD2="${2:?No command 2 specified...}"
  local PIPE1="${3:-3}"
  local PIPE2="${4:-4}"
  local PIPE3="${5:-5}"
  eval "exec ${PIPE2}>&1 ${PIPE3}>&2"
  local ERR=$(eval "{ { { "$CMD1"; }; echo \$? >&${PIPE1}; } | { "$CMD2"; }; } ${PIPE1}>&1 >&${PIPE2} 2>&${PIPE3}")
  eval "exec ${PIPE2}>&- ${PIPE3}>&-"
  return $ERR
}
#mispipe() {
#    local CMD1="${1:?No command 1 specified...}"
#    local CMD2="${2:?No command 2 specified...}"
#    exec 4>&1 5>&1
#    local ERR=$({ { { $CMD1; }; echo $? >&3; } | { $CMD2; }; } 3>&1 >&4 2>&5)
#    exec 4>&- 5>&-
#    return $ERR
#}

# Filter stderr using unamed pipes
# https://unix.stackexchange.com/questions/3514/how-to-grep-standard-error-stream-stderr
if [ -n "$BASH_VERSION" ]; then
  # Ex: cmd1 2> >(cmd2)
  filter_stderr() {
    local CMD1="${1:-true}"
    local CMD2="${2:-true}"
    eval "{ ${CMD1}; } 2> >(${CMD2})"
  }
else
  # Ex: { cmd1 2>&1 1>&3 | cmd2 1>&2; } 3>&1
  # Errcode: cmd2
  filter_stderr_simple() {
    local CMD1="${1:-true}"
    local CMD2="${2:-true}"
    local PIPE="${3:-3}"
    eval "{ { ${CMD1}; } 2>&1 1>&${PIPE} | ${CMD2} 1>&2; } ${PIPE}>&1"
  }
  # Ex: return $({ { cmd1 3>&1 1>&2 2>&3; echo $? >&4; } | cmd2 >&2; } 4>&1)
  # Errcode: cmd1
  filter_stderr() {
    local CMD1="${1:-true}"
    local CMD2="${2:-true}"
    local PIPE1="${3:-3}"
    local PIPE2="${4:-4}"
    return $(eval "{ { { ${CMD1}; } ${PIPE1}>&1 1>&2 2>&${PIPE1}; echo \$? >&${PIPE2}; } | { ${CMD2}; } >&2; } ${PIPE2}>&1")
  }
fi

################################
# Send / receive messages using named pipes

# Send msg into named pipe
msg_send() {
  local MSG="$1"
  local TIMEOUT="${2:-0}"
  local PIPE="${3:-$(dirname $(mktemp -u))/msg}"
  crpipe "$PIPE" >/dev/null 2>&1 || return 1
  timeout "$TIMEOUT" sh -c '
    echo "$1" > "$2"
  ' _ "$MSG" "$PIPE"
  # Don't delete the pipe, someone is still reading from it
}

# Wait msg from named pipe
msg_wait() {
  local MSG="$1"
  local TIMEOUT="${2:-0}"
  local PIPE="${3:-$(dirname $(mktemp -u))/msg}"
  local KEEP="$4"
  crpipe "$PIPE" >/dev/null 2>&1 || return 1
  timeout "$TIMEOUT" sh -c '
    while read M < "$2"; do
      [ -z "$1" ] || [ "$1" = "$M" ] && exit 0
    done
  ' _ "$MSG" "$PIPE"
  local RET=$?
  [ -z "$KEEP" ] && [ -p "$PIPE" ] && rm "$PIPE" 2>/dev/null
  return $RET
}

################################
# Handshake procedures

# Handshake between 2 peers
# Known issue: the timeouts must be large enough for the shell and its scripts to be spawn
handshake() {
  local PIPE="$(crpipe "${1:-$(dirname $(mktemp -u))/pipe}")" || return 1
  local TIMEOUT="${2:-0}"
  timeout 0.1 sh -c "cat </dev/null >\"$PIPE\""
  timeout --foreground "$TIMEOUT" sh -c "cat >/dev/null <\"$PIPE\""
  timeout 0.1 sh -c "cat </dev/null >\"$PIPE\""
  return 0
}
handshake1() { handshake "$(dirname $(mktemp -u))/pipe1"; }
handshake2() { handshake "$(dirname $(mktemp -u))/pipe2"; }
handshake3() { handshake "$(dirname $(mktemp -u))/pipe3"; }

# Handshakes between N peers, 1 to 1
handshakes() {
  local MAX="${1:-1}"
  local PIPE="${2:-$(dirname $(mktemp -u))/pipe}"
  local TIMEOUT="${3:-0}"
  local NUM=$(($(ps -e | grep timeout | wc -l) + 1))
  if [ $NUM -lt $MAX ]; then
    handshake "${PIPE}${NUM}"
    handshake "${PIPE}$(($NUM + 1))"
  else
    handshake "${PIPE}1"
    handshake "${PIPE}${MAX}"
  fi
}

################################
# Execute a cmd, block until stdin sees a specified regex, then execute an optional command in the background
expected() {
  local CMD="$1"
  local TRAP="${2:-true}"
  local REGEX1="$3"
  local CMD1="$4"
  local REGEX2="$5"
  local CMD2="$6"
  local REGEX3="$7"
  local CMD3="$8"
  local REGEX4="$9"
  local CMD4="${10}"
  local LOOP="${11:-1}"
  local TIMEOUT="${12:--1}"
  local NOP1; [ -z "$REGEX1" ] && NOP1="#" || NOP1=""
  local NOP2; [ -z "$REGEX2" ] && NOP2="#" || NOP2=""
  local NOP3; [ -z "$REGEX3" ] && NOP3="#" || NOP3=""
  local NOP4; [ -z "$REGEX4" ] && NOP4="#" || NOP4=""
  expect - <<EOF
    proc myexec {cmdline cmdid} {
      global counts
      set counts(\$cmdid) [expr \$counts(\$cmdid) + 1]
      if {[regexp "^exec (.*)" \$cmdline all cmd]} {
        catch { exec -- sh -c ":; \$cmd" & } out
      } else {
        eval "\$cmdline"
      }
      return [expr [string length {$LOOP}] != 0 ]
    }
    set timeout $TIMEOUT
    array set counts [list cmd1 0 cmd2 0 cmd3 0 cmd4 0]
    trap {
      exec -keepnewline -ignorestderr -- sh -c ":; set +e; $TRAP; true"
      catch { exec -- sh -c ":; pkill -9 -P [pid]; true" } out
      exit
    } { SIGINT SIGTERM }
    spawn -noecho sh -c {:; $CMD}
    expect {
      $NOP1 -re {$REGEX1} { if { [myexec {$CMD1} cmd1] } { exp_continue } }
      $NOP2 -re {$REGEX2} { if { [myexec {$CMD2} cmd2] } { exp_continue } }
      $NOP3 -re {$REGEX3} { if { [myexec {$CMD3} cmd3] } { exp_continue } }
      $NOP4 -re {$REGEX4} { if { [myexec {$CMD4} cmd4] } { exp_continue } }
    }
EOF
}

################################
# Cmd exist test
cmd_exists() {
  local CMD
  for CMD; do
    command -v "$CMD" >/dev/null 2>&1 || return 1
  done
  return 0
}

# Cmd unset
cmd_unset() {
  unalias $* 2>/dev/null || true
  unset -f $* 2>/dev/null
}

# Unalias a script commands
cmd_unalias() {
  local FILE
  local FCT
  for FILE; do
    for FCT in $(awk -F'(' '/\w\s*\(\)/ {print $1}' "$FILE"); do
      unalias "$CMD" 2>/dev/null || true
    done
  done
}

# Unalias all existing commands
cmd_unalias_all() {
  local CMD
  for CMD in $(set | grep " () $" | cut -d" " -f1); do
    unalias "$CMD" 2>/dev/null || true
  done
}

################################
# Verbose run
verbose() { echo "$@" >&2 && "$@"; }

# Silent run
alias noerror='2>/dev/null'
alias noerr='2>/dev/null'
alias noout='>/dev/null'
alias silent='>/dev/null 2>&1'

# which replacement when missing
cmd_exists which ||
which() {
  local IFS=:
  local DIR
  [ $# -gt 0 ] &&
    for DIR in $PATH; do
      ls -1 "$DIR/$1" 2>/dev/null && return 0
    done
  return 1
}

################################
# EINTR retry fct
#http://unix.stackexchange.com/questions/16455/interruption-of-system-calls-when-a-signal-is-caught
eintr() {
  local EINTR=4
  eval "$@"
  while [ $? -eq $EINTR ]; do
    eval "$@"
  done
}

################################
# Attach terminal to process
# https://unix.stackexchange.com/questions/31824/how-to-attach-terminal-to-detached-process
# Alternative: reptyr
shell_attach() {
  PID="${1:?No PID specified...}"
  STDIN="${2}"
  STDOUT="${3}"
  GDBINIT="$(mktemp)"
  rm "$GDBINIT" 2>/dev/null
  if [ -n "$STDIN" ]; then
    echo "call close(0)" >> "$GDBINIT"
    echo "call open(\"$STDIN\", 0600)" >> "$GDBINIT"
    [ ! -f "$STDIN" ] && mkfifo "$STDIN"
  fi
  if [ -n "$STDOUT" ]; then
    echo "call close(1)" >> "$GDBINIT"
    echo "call open(\"$STDOUT\", 0400)" >> "$GDBINIT"
    touch "$STDOUT"
  fi
  echo "continue" >> "$GDBINIT"
  echo "quit" >> "$GDBINIT"
  sudo sh -c "gdb -p \"$PID\" -nh -nx -x \"$GDBINIT\""
}

################################
# Implement a basic lock (simple but with a race condition flaw)
shell_block_take() {
  local FILE="${1:?No lock file specified...}"
  if [ -e "${FILE}" ] && kill -0 "$(cat "${FILE}")"; then
    return 1
  fi
  trap 'rm -f "${FILE}"; exit' INT TERM EXIT
  echo $$ > "${FILE}"
}
shell_block_release() {
  trap '' INT TERM EXIT
  rm -f "${FILE}"
}

#~ Traditional form using flock
#~ exec 9> /tmp/mylockfile || return 1
#~ flock 9 || return 2
#~ trap "exec 9>&-; flock -u 9; rm -f /tmp/mylockfile; trap '' INT TERM EXIT; exit" INT TERM EXIT
#~ # ...

# Convenient form using flock
#~ (
#~   flock 9
#~   # ...
#~ ) 9>/tmp/mylockfile

# Implement locks with flock
shell_flock_take() {
  local FILE="${1:?No lock file specified...}"
  local DESCR="${2:-9}" # dash cannot open more than 10 file handlers
  local TIMEOUT="$3" # 0=fail immediatly; if not specified, then wait until lock available
  local TYPE="${4:--x}" # -x = exclusive (write), -s = shared (read)
  exec "$DESCR"> "$FILE" || return 1
  flock ${TIMEOUT:+-w "$TIMEOUT"} ${TYPE} "$DESCR" || return 2
  trap "shell_flock_release '$FILE' '$DESCR'; trap '' INT TERM EXIT; exit" INT TERM EXIT
  return 0
}
shell_flock_release() {
  local FILE="${1:?No lock file specified...}"
  local DESCR="${2:-9}"
  flock -u "$DESCR"
  exec "$DESCR"<&-
  rm -f "$FILE"
}

################################
# Return shell option string
# Save: MYVAR="$(shell_getopts)"
# Restore: eval "$MYVAR" # quotes are important
shell_getopts() {
  set +o
  shopt -p 2>/dev/null
}

################################
# Dash array exemples & positional parameters save/restore
#~ shell_array_exemple() {
  #~ local SAVE=$(printf '%q ' "$@")
  #~ local NUM=$#
  #~ set --
  #~ echo "Clear all $# : $@"
  #~ eval set -- $SAVE
  #~ echo "params $# : $@"
  #~ for P in $(seq $NUM); do
    #~ echo "param #$P : $1"
    #~ shift
  #~ done
#~ }
