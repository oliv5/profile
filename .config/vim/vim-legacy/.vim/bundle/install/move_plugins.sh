#!/bin/sh
[ "$DBG" = 2 ] && set -vx
DBG=${DBG:+echo}

#~ for P in *[^~]; do
    #~ if [ -d "$P" ] && ! [ -e "$P~" ] && [ "$P" != "pathogen" ]; then
	#~ $DBG git mv "$P" "$P~" || mv "$P" "$P~" || continue
	#~ $DBG ln -s "$P~" "$P"
    #~ fi
#~ done

for P in *; do
    [ "$P" = "pathogen" ] && continue
    [ "$P" = "plugins" ] && continue
    if [ -d "$P" ] && ! [ -h "$P" ] && ! [ -e "plugins/$P" ]; then
	$DBG git mv "$P" "plugins/$P" || mv "$P" "plugins/$P" || continue
	$DBG ln -s "plugins/$P" "$P"
    fi
done
