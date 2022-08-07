#!/bin/sh
SRC="${1:-$PWD}"
for FILE in "${SRC}"/*.desktop; do
    [ -e "${FILE}" ] && 
        ln -fsv "${FILE}" "${HOME}/.local/share/applications/$(basename "${FILE}")"
done
for FILE in "${SRC}"/*.png "${SRC}"/*.ico; do
    [ -e "${FILE}" ] && 
        ln -fsv "${FILE}" "${HOME}/.local/share/icons/$(basename "${FILE}")"
done

