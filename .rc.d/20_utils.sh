#!/bin/sh

################################
# Ask question and expect one of the given answer
# ask_question [fd number] [question] [expected replies]
ask_question() {
  # -- Generic part --
  local REPLY
  local STDIN=/dev/fd/0
  if [ -c "/dev/fd/$1" ]; then
    STDIN=/dev/fd/$1
    shift $(min 1 $#)
  fi
  read ${1:+-p "$1"} REPLY <${STDIN}
  shift $(min 1 $#)
  # -- Custom part --
  echo "$REPLY"
  for ACK; do
    [ "$REPLY" = "$ACK" ] && return 0
  done
  return 1
}

# Get answers
question() {
    local Q="${1:?No question specified...}"
    local D="$2"
    echo -n "$Q ${D:+('$D') }: " >&2
    local A; read -r A
    [ -z "$A" ] && echo "$D" || echo "$A"
}
question2() {
    local Q="$1" D="$2"
    shift 2
    local A=""
    while ! arg_is_in "$A" "$@" ; do
        A="$(question "$Q" "$D")"
    done
    echo "$A"
}
question_v() {
    local _V="${1:?No variable specified...}"
    shift; local A="$(question "$@")"
    shift; [ -z "$A" ] && eval $_V="$@" || eval $_V="$A"
}
question2_v() {
    local _V="${1:?No variable specified...}"
    local Q="$2" D="$3"
    shift 3
    eval $_V="$(question2 "$Q" "$D" "$@")"
}
confirmation() {
    local V
    question_v V "$1 (y/n)"
    [ "$V" = "y" ] || [ "$V" = "Y" ] 
}

################################
# Ask for a file
# ask_file [fd number] [question] [file test] [default value]
ask_file() {
  # -- Generic part --
  local REPLY
  local STDIN=/dev/fd/0
  if [ -c "/dev/fd/$1" ]; then
    STDIN=/dev/fd/$1
    shift $(min 1 $#)
  fi
  read ${1:+-p "$1"} REPLY <${STDIN}
  shift $(min 1 $#)
  # -- Custom part --
  [ -z "$REPLY" ] && REPLY="$2"
  echo "$REPLY"
  test ${1:-e} "$REPLY"
}

# Get password
ask_passwd() {
  local PASSWD
  trap "stty echo; trap - INT TERM QUIT EXIT" INT TERM QUIT EXIT
  stty -echo
  read -p "${1:-Password: }" PASSWD
  stty echo
  trap - INT TERM QUIT EXIT
  echo -n $PASSWD
}

################################
# Run command in loop until criteria is met (n times, error code)
alias sudo_rerun='fct_sudo rerun'
rerun() {
  local EXPECTED="" #expected error code to stop
  local REJECTED="" #error code to avoid
  local LIMIT="-1" #infinite
  local PAUSE=0
  local TRIALS=0
  local RET
  if [ -z "$1" ] || expr 2 "*" "$1" + 1 > /dev/null 2>&1; then
    EXPECTED="$1"
    shift
  fi
  if [ -z "$1" ] || expr 2 "*" "$1" + 1 > /dev/null 2>&1; then
    REJECTED="$1"
    shift
  fi
  if [ -z "$1" ] || expr 2 "*" "$1" + 1 > /dev/null 2>&1; then
    LIMIT="${1:--1}"
    shift
  fi
  if [ -z "$1" ] || expr 2 "*" "$1" + 1 > /dev/null 2>&1; then
    PAUSE="${1:-0}"
    shift
  fi
  : ${1:?No command to execute...}
  while [ "$TRIALS" != "$LIMIT" ]; do
    TRIALS=$(($TRIALS + 1))
    "$@"; RET=$?
    [ "$RET" = "$EXPECTED" ] && break
    [ "$RET" != "${REJECTED:-$RET}" ] && break
    [ "$TRIALS" = "$LIMIT" ] && break
    sleep $PAUSE
  done
  return $TRIALS
}

# Loop forever
alias sudo_loop='fct_sudo loop'
loop() { rerun "" "" -1 "$@"; }

# Repeat n times
alias sudo_repeat='fct_sudo repeat'
repeat() { rerun "" "" "$@"; }

# Retry in loop until success
alias sudo_retry='fct_sudo retry'
retry() { 
  trap 'echo Interrupted after $TRIALS trials; trap - INT TERM; exit;' INT TERM
  rerun 0 "" "$@"
  echo "Ended after $? trial(s)"; trap - INT TERM
}

# Stress run in loop until error
alias sudo_stress='fct_sudo stress'
stress() {
  trap 'echo Interrupted after $TRIALS trials; trap - INT TERM; exit;' INT TERM
  rerun "" "$@"
  echo "Ended after $? trial(s)"; trap - INT TERM
}

########################################
# User sort helper
usersort() {
  local NUM="${NUM:-$1}"
  local REV="${REV:-$2}"
  local UNIQ="${UNIQ:-$3}"
  local ZERO="${ZERO:-$4}"
  eval sort ${UNIQ:+-u} ${ZERO:+-z} ${REV:+-r} ${NUM:+| head ${ZERO:+-z} -n $NUM} </dev/stdin
}

########################################
########################################
# Last commands in file
# Execute function from command line
if [ -n "$1" ]; then "$@"; else true; fi
