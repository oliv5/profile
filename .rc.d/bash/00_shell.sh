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
