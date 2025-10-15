#!/bin/sh

# Ansi codes
# https://tldp.org/HOWTO/Bash-Prompt-HOWTO/x361.html
# http://man7.org/linux/man-pages/man4/console_codes.4.html
# https://en.wikipedia.org/wiki/ANSI_escape_code
#Black        0;30     Dark Gray     1;30
#Blue         0;34     Light Blue    1;34
#Green        0;32     Light Green   1;32
#Cyan         0;36     Light Cyan    1;36
#Red          0;31     Light Red     1;31
#Purple       0;35     Light Purple  1;35
#Brown/Orange 0;33     Yellow        1;33
#Light Gray   0;37     White         1;37
# To use it:
## export RED='\033[0;31m'
## export NC='\033[0m' # No Color
## echo -e "I ${RED}love${NC} Stack Overflow"
## printf "I ${RED}love${NC} Stack Overflow\n"
## echo -en "\033[s\033[7A\033[1;32m 7 lines up green \033[u\033[0m"
## echo -en "\033[s\033[7B\033[1;34m 7 lines down violet \033[u\033[0m"
ansi_export_codes() {
  export NC='\033[0m' # No Color
  export BLACK='\033[0;30m'
  export BLUE='\033[0;34m'
  export GREEN='\033[0;32m'
  export CYAN='\033[0;36m'
  export RED='\033[0;31m'
  export PURPLE='\033[0;35m'
  export ORANGE='\033[0;33m'
  export LGRAY='\033[0;37m'
  export DGRAY='\033[1;30m'
  export LBLUE='\033[1;34m'
  export LGREEN='\033[1;32m'
  export LCYAN='\033[1;36m'
  export LRED='\033[1;31m'
  export LPURPLE='\033[1;35m'
  export YELLOW='\033[1;33m'
  export WHITE='\033[1;37m'
}
ansi_codes() {
  local NC='\033[0m' # No Color
  local BLACK='\033[0;30m'
  local BLUE='\033[0;34m'
  local GREEN='\033[0;32m'
  local CYAN='\033[0;36m'
  local RED='\033[0;31m'
  local PURPLE='\033[0;35m'
  local ORANGE='\033[0;33m'
  local LGRAY='\033[0;37m'
  local DGRAY='\033[1;30m'
  local LBLUE='\033[1;34m'
  local LGREEN='\033[1;32m'
  local LCYAN='\033[1;36m'
  local LRED='\033[1;31m'
  local LPURPLE='\033[1;35m'
  local YELLOW='\033[1;33m'
  local WHITE='\033[1;37m'
  for F; do
    eval echo "\${$F}"
  done
}
ansi_echo() {
  local CODE="${1:-NC}"; shift
  echo -e "$(ansi_codes "$CODE")$*$(ansi_codes "NC")"
}
ansi_printf() {
  local CODE="${1:-NC}"; shift
  printf "$(ansi_codes "$CODE")$*$(ansi_codes "NC")"
}

# Remove/strip ANSI codes
alias ansi_strip='sed "s/\x1b\[[0-9;]*m//g"'
alias ansi_rm='sed -i "s/\x1b\[[0-9;]*m//g"'

# Find non-ascii characters
alias ansi_show_non_ascii='grep --color="auto" -P -n "[^\x00-\x7F]"'

# Remove non-ascii char
show_non_ascii_line() {
  for FILE in "${@:-/dev/stdin}"; do
    awk '{for(i=1; i<=length; i++){c=substr($0,i,1); if (c ~ /[^ -~]/) print NR ": " $0}}' "$FILE"
  done
}

# Force remove non-ascii char in file
# https://techkluster.com/linux/find-non-ascii-chars/
force_ascii() {
  for FILE in "${@:-/dev/stdin}"; do
    tr -d -c '[:print:]\t\n' < "$FILE"
  done
}

# Success display function
msg_success() {
  echo -ne "\33[32m[✔]\33[0m" "$@"
}

# Error display function
msg_error() {
  echo -ne "\33[31m[✘]\33[0m" "$@"
}

# Erase
erase_eol() {
  echo -ne "\033[K"
}
clear_screen() {
  echo -ne '\x1b[H\x1b[2J\x1b[3J'
}

# Move cursor
cursor_xy() {
  echo -ne "\033[$2;$1H"
}
cursor_left() {
  echo -ne "\e[${1:-1}D"
}
cursor_right() {
  echo -ne "\e[${1:-1}C"
}
cursor_up() {
  echo -ne "\e[${1:-1}A"
}
cursor_down() {
  echo -ne "\e[${1:-1}B"
}

# Counters
count() {
  for F in $(seq ${1:-1} ${3:-1} ${2:-${1:-1}}); do
    echo -n "$5$F"
    sleep ${4:-1}
    cursor_left $(($F / 10 + 1))
    erase_eol
  done
}
count_up() {
  local A="${1:-1}"
  local B="${2:-1}"
  [ "$A" -gt "$B" ] && { local C="$A"; A="$B"; B="$C"; }
  count $A $B 1 "$3"
}
count_down() {
  local A="${1:-1}"
  local B="${2:-1}"
  [ "$A" -lt "$B" ] && { local C="$A"; A="$B"; B="$C"; }
  count $A $B -1 "$3"
}

# Resize console
# https://unix.stackexchange.com/questions/16578/resizable-serial-console-window#283206
# Inspired from https://wiki.archlinux.org/index.php/working_with_the_serial_console#Resizing_a_terminal
console_resize() {
  local old=$(stty -g)
  stty raw -echo min 0 time 5

  printf '\0337\033[r\033[999;999H\033[6n\0338' > /dev/tty
  IFS='[;R' read -r _ rows cols _ < /dev/tty

  stty "$old"

  # echo "cols:$cols"
  # echo "rows:$rows"
  stty cols "$cols" rows "$rows"
}

# Inspired from https://github.com/ThomasDickey/xterm-snapshots/blob/master/vttests/resize.sh
console_resize_v2() {
  local old=$(stty -g)
  stty raw -echo min 0 time 5

  printf '\033[18t' > /dev/tty
  IFS=';t' read -r _ rows cols _ < /dev/tty

  stty "$old"

  # echo "cols:$cols"
  # echo "rows:$rows"
  stty cols "$cols" rows "$rows"
}

# Show all unicode chars
# https://unix.stackexchange.com/questions/337980/how-can-i-print-utf-8-and-unicode-tables-from-the-terminal/337989#337989
show_unicode_chars() {
  for y in $(seq 0 524287); do
    for x in $(seq 0 7); do
      a=$(expr $y \* 8 + $x)
      echo -ne "$a \\u$a "
    done
    echo
  done
}
