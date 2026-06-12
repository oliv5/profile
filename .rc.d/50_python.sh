#!/bin/sh

# List dependencies (one level)
py_deps() {
  local PKG="${1:?No package name specified...}"
  local VER="$2"
  PKG="$(echo "$PKG" | sed -e 's/>=/==/')"
  if [ "${PKG%==*}" != "$PKG" ]; then
    VER="${PKG#*==}"
    PKG="${PKG%==*}"
  fi
  python <<-EOF
import requests
package_name = "$PKG"
package_version = "$VER"
url = f'https://pypi.org/pypi/{package_name}/{package_version}/json'
response = requests.get(url).json()
dependencies = response['info']['requires_dist']
for d in dependencies:
  print(d)
EOF
}

# List dependencies recursively. May not work yet
py_recursive_deps() {
  for P in $(py_deps "$@"); do
    py_recursive_deps "$P"
  done
}
