#!/bin/sh
SRC="${1:-$PWD}"

for FILE in "${SRC}"/*.png "${SRC}"/*.ico; do
    DST="${HOME}/.local/share/icons/$(basename "${FILE}")"
    if [ -e "${FILE}" ]; then
        ln -fsv "${FILE}" "${DST}"
    fi
done

for FILE in "${SRC}"/*.desktop; do
    DST="${HOME}/.local/share/applications/$(basename "${FILE}")"
    if [ -e "${FILE}" ]; then
        ln -fsv "${FILE}" "${DST}.link"

        [ -e "${DST}" ] && rm -v "${DST}"
        cp -v "${FILE}" "${DST}"
        
        ICON="$(awk -F= '/Icon=/{print $2}' "${DST}")"
        ICON="${HOME}/.local/share/icons/$ICON"
        [ -e "${ICON}.ico" ] && ICON="${ICON}.ico"
        [ -e "${ICON}.png" ] && ICON="${ICON}.png"
        sed -i -e "s;Icon=\([^\/]*\)\$;Icon=${ICON};" "${DST}"
    fi
done

update-desktop-database ~/.local/share/applications
