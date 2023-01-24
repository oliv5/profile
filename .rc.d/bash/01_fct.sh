#!/bin/bash
# http://tldp.org/LDP/abs/html/

# List user functions
fct_ls() {
  declare -F | cut -d" " -f3
}

# Export user functions from script
fct_export() {
  export -f "$@"
}

# Export all user functions
fct_export_all() {
  export -f $(fct_ls)
}

# Remove function
fct_unset() {
  unset -f "$@"
}

# Print fct content
fct_content() {
  type ${1:?No fct name given...} 2>/dev/null | tail -n+4 | head -n-1
}
