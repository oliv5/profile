#!/bin/sh
# Do not load when not installed
if command -v screen >/dev/null; then

# SSH autoload
if [ -z "$STY" -a -n "$SSH_CONNECTION" -a "${SCREEN_AUTOLOAD#*ssh}" != "$SCREEN_AUTOLOAD" ]; then
  SCREEN_AUTOLOAD="yes"
fi

# Wrapper function
screen() {
  if [ $# = 0 ]; then
    # Recall old session or create a new one
    command -p screen -R
  else
    # Execute command normally
    command -p screen "$@"
  fi
}

# Check if screen session is running
screen_is_running() {
  command screen -ls "$1" >/dev/null 2>&1
}

# Run screen command (screen, stuff, exec, quit, ...) in specific session
screen_cmd() {
  local SESSION="${1:?No session specified...}"
  shift
  command -p screen -S "$SESSION" -X "$@"
}

# Send a shell command to a running screen. Does not press enter
screen_send() {
  local SESSION="${1:?No session specified...}"
  shift
  command -p screen -S "$SESSION" -X stuff "^C\n${@}\n"
}

# Run a shell command in an existing named session or in a new named one
screen_run() {
  local SESSION="${1:?No session specified...}"
  shift
  if screen_is_running "$SESSION"; then
    command -p screen -S "$SESSION" -X screen "$@"
  else
    command -p screen -S "$SESSION" -d -m "$@"
  fi
  echo "$SESSION"
}

# Execute a shell command in the first session available or in a new one
screen_exec() {
  local SESSION="$(command screen -ls | awk '/^\t/{print $1; exit}')"
  if [ -n "$SESSION" ]; then
    command -p screen -S "$SESSION" -X screen "$@"
    echo "$SESSION"
  else
    command -p screen -d -m "$@"
    screen_ls
  fi
}

# Run a shell command in loop; replace $N with the loop index starting from 1
screen_loop() {
  local N="${1:?No loop number specified...}"
  N=$(($N)) # default 0
  shift
  echo "Stop with: screen -S loop -X quit"
  for N in $(seq $N); do
    eval screen_run loop "$@"
  done
}

# Kill a session
screen_kill() {
  for S; do
    command screen -S "$S" -X quit # -S before -X
  done
}

# Set $DISPLAY
screen_setdisplay() {
  screen_send "$1" "export DISPLAY=$DISPLAY"
}

# List screen sessions
screen_ll() {
  command -p screen -q -ls
  if [ $? -ne 9 ]; then
    command screen -ls
  fi
}

# List screen sessions name only
screen_ls() {
  command screen -ls | awk '/^\t/{print $1}'
}

# Long aliases
alias screen_recall='screen -r'
alias screen_restore='screen -R -D'
alias screen_killdetached="screen -ls | awk -F. '/Detached/{print \$1}' | xargs -r kill"
alias screen_killall="screen -ls | awk -F. '/^\t/{print \$1}' | xargs -r kill"
alias screen_clean='screen -wipe'
alias screen_attach='reptyr'
alias screen_detach='screen -d -m'

# Autoload
if [ -z "$STY" -a -z "$SCREEN_LOADED" ]; then
  if [ "$SCREEN_AUTOLOAD" = "yes" ] && shell_isinteractive && shell_islogin; then
    screen_restore 2> /dev/null
  fi
fi

# Flag
export SCREEN_LOADED=1

########################################
########################################
# Last commands in file
# Execute function from command line
[ "${1#screen}" != "$1" ] && "$@" || true

fi
