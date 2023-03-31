Multiple ways to install macros:
1) copy them in the Base/ project folder; add them to the Base project; re-source all files.
2) link them in your project tree file; add them to the project; re-source all files.
3) list them with your included files; add them to the project; re-source all files.
   ex: find "$HOME/.config/profile/sourceinsight/si4/macros/" -maxdepth 1 -type f -name '*.em' -print0 | xargs -r0 realpath -m --relative-to="$PWD"
