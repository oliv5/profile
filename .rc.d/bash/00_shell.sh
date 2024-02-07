#!/bin/bash
# http://tldp.org/LDP/abs/html/

################################
#http://www.tldp.org/LDP/abs/html/intandnonint.html

# Returns true for interactive shells
shell_isinteractive() {
  [ -n "$PS1" ]
}

# Returns true for login shells
shell_islogin() {
  shopt -q login_shell
}

# Get script directory
shell_pwd() {
  echo $( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
}

################################
# Check bashism in scripts
bash_checkbashisms() {
  command -v checkbashisms >/dev/null 2>&1 || die "checkbashisms not found..."
  find "${1:-.}" -name "${2:-*.sh}" -exec sh -c 'checkbashisms {} 2>/dev/null || ([ $? -ne 2 ] && echo "checkbashisms {}")' \;
}

# Setup command completion
bash_completion() {
  complete -o bashdefault -o default -o nospace -F "$2" "$1" 2>/dev/null \
  || complete -o default -o nospace -F "$2" "$1"
}

################################
# Auto-quote current line
# https://superuser.com/questions/1531395/how-can-i-single-quote-or-escape-the-whole-command-line-in-bash-conveniently
_quote_all() { READLINE_LINE="${READLINE_LINE@Q}"; READLINE_POINT=0; }
bind -x '"\C-x\C-x":_quote_all'
