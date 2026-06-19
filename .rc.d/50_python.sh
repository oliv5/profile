#!/bin/sh

# List dependencies (one level)
py_deps() {
  local PKG="${1:?No package name specified...}"
  local VER="$2"
  PKG="$(echo "$PKG" | sed -e 's/>=/==/' -e 's/;.*//')"
  if [ "${PKG%==*}" != "$PKG" ]; then
    VER="${PKG#*==}"
    PKG="${PKG%==*}"
  fi
  python 2>/dev/null <<EOF | grep -v implementation_name | grep -v python_version
import requests
package_name = '$PKG'
package_version = '$VER'
url = f'https://pypi.org/pypi/{package_name}/{package_version}/json'
response = requests.get(url).json()
if 'info' in response and 'requires_dist' in response['info']:
  dependencies = response['info']['requires_dist']
  if dependencies is not None:
    for d in dependencies:
      print(d)
EOF
}

# List dependencies recursively. May not work yet
py_recursive_deps() {
  local N="${2:-}"
  for P in $(py_deps "$1"); do
    if [ "$P" != "$1" ]; then
      echo "${N}${P}"
      py_recursive_deps "$P" "${N} "
    fi
  done
}
