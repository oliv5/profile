#!/bin/sh

# Returns true when a given method exists and is selected
_exists() {
  command -v "$1" >/dev/null 2>&1 &&
    { [ -z "$2" ] || [ "$2" = "$1" ]; }
}

# Log and run
_run() {
  echo >&2 "$@"; "$@"
}

# Execute the WOL command
_execute_wol() {
  local METHOD="${1:?No wol method specified...}"
  local MAC="${2:?No MAC address specified...}"
  local IP="$3"
  local PORT="${4:-9}"
  local ITF="$5"
  local MASK="255.255.255.255"
  local URL

  if _exists wakeonlan "$METHOD"; then
    MAC="$(echo $MAC | sed 's/-/:/g')"
    _run wakeonlan -i "$IP" -p "$PORT" "$MAC"
  elif _exists etherwake "$METHOD"; then
    _run etherwake -i "${ITF:?No interface specified...}" -b "$MAC"
  elif [ "$METHOD" = "web" ] || [ "${METHOD%%s://*}" = "http" ]; then
    MAC="$(echo $MAC | sed 's/:\|-//g')"
    [ -z "$IP" ] && IP="$(curl -qs icanhazip.com)"
    if [ "$METHOD" = "web" ]; then
      URL="https://www.depicus.com/wake-on-lan/woli?m=${MAC}&i=${IP}&s=${MASK}&p=${PORT}"
    else
      # Evaluate \$VARIABLES
      eval URL="\"$METHOD\""
    fi
    if command -v curl >/dev/null; then
      _run curl -qs "$URL" >/dev/null
    elif command -v wget >/dev/null; then
      _run wget --timeout=10 -q -O /dev/null "$URL"
    else
      echo "Open this URL in your web browser: $URL"
    fi
  else
    echo >&2 "Unknown WOL method ($METHOD)..."
    return 1
  fi
  return 0
}

# Main
if [ $# -eq 0 ]; then
  echo >&2 "Usage: wol.sh <wakeonlan|etherwake|web|http(s)://...> [MAC] [IP] [PORT] [ITF]"
  false
else
  _execute_wol "$@"
fi
