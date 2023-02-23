#!/bin/sh

cat <<EOF
Multiple ways to install macros:
1) copy them in the Base/ project folder
2) link them in your project tree file
3) list them with your included files
   ex: find "$HOME/.config/profile/sourceinsight/si4/macros/" -maxdepth 1 -type f -name '*.em' -print0 | xargs -r0 realpath -m --relative-to="$PWD"
IMPORTANT: in all cases, they must be included in your project file tree and sourced.
EOF
