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

# Extract some parameters
_get_wol_params() {
  eval MAC="${1:-\${${PROFILE}_MAC:?No MAC address defined...}}"
  eval IP="${2:-\${${PROFILE}_IP:-255.255.255.255}}"
  eval PORT="${3:-\${${PROFILE}_PORT:-9}}"
  ITF="${4:-eth0}"
  # Convert '-' into ':'
  MAC="$(echo $MAC | tr '-' ':' | tr '[:lower:]' '[:upper:]')"
}
_get_ssh_params() {
  SSH_CREDS="${1:?No SSH host/credentials specified...}"
  SSH_PARAMS="$2"
}

# Print known wol URLs
_urls() {
  echo "https://www.depicus.com/wake-on-lan/woli?m=${MAC}&i=${IP}&s=255.255.255.255&p=${PORT}"
}

# Execute the WOL command
_execute_wol() {
  local PROFILE="$(echo $1 | tr '[:lower:]' '[:upper:]')"
  local METHOD="$2"
  shift $(($# < 2 ? $# : 2))

  if _exists wakeonlan "$METHOD"; then
    _get_wol_params "$@"
    _run wakeonlan -i "${IP}" -p "${PORT}" "${MAC}";
  elif _exists wol "$METHOD"; then
    _get_wol_params "$@"
    _run wol -i "${IP}" -p "${PORT}" "${MAC}"
  elif _exists etherwake "$METHOD"; then
    _get_wol_params "$@"
    _run etherwake -i "${ITF}" -b "${MAC}"
  elif _exists ether-wake "$METHOD"; then
    _get_wol_params "$@"
    _run ether-wake -i "${ITF}" -b "${MAC}"
  elif _exists curl "$METHOD"; then
    _get_wol_params "$@"
    for URL in $(_urls); do
      _run curl -qs "${URL}" >/dev/null && break
    done
  elif _exists wget "$METHOD"; then
    _get_wol_params "$@"
    for URL in $(_urls); do
      _run wget --timeout=10 -q -O /dev/null "${URL}" && break
    done
  elif _exists ssh "$METHOD"; then
    local SSH_CREDS="${1:?No SSH host/credentials specified...}"
    local METHOD="$2"; [ "$METHOD" = "ssh" ] && METHOD=""
    shift $(($# < 2 ? $# : 2))
    ssh "$SSH_CREDS" -- sh -c ':; . "$HOME/bin/profile/wol.sh" "$@"' "$PROFILE" "$METHOD" "$@"
  else
    echo >&2 "No appropriate WOL method available..."
    false
  fi
}

# Main
if [ $# -eq 0 ]; then
  echo >&2 "Usage: wol.sh <profile> <method> [method params...]"
  false
else
  _execute_wol "$@"
fi
