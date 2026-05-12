#!/bin/bash +e
# https://unix.stackexchange.com/questions/46478/join-the-executable-and-all-its-libraries
[ -n "$1" ] || set -- a.out

mkdir -p ./pack

# Use ldd to resolve the libs and use `patchelf --print-needed to filter out
# "magic" libs kernel-interfacing libs such as linux-vdso.so, ld-linux-x86-65.so or libpthread
# which you probably should not relativize anyway
#~ join \
    #~ <(ldd "$1" | awk '{if(substr($3,0,1)=="/") print $1,$3}' | sort) \
    #~ <(patchelf --print-needed "$1" | sort) | cut -d\  -f2 |
	#~ xargs -d '\n' -I{} cp -v --copy-contents {} ./pack

# Make the relative lib paths override the system lib path
#~ cp -v -L --copy-contents "$1" ./pack
#~ patchelf --set-rpath "\$ORIGIN" "./pack/$(basename "$1")"

copy_deps() {
    cp -v -L --copy-contents "$1" ./pack
    patchelf --set-rpath "\$ORIGIN" "./pack/$(basename "$1")"
    for F in $(ldd "$1" | awk '{if(substr($3,0,1)=="/") {print $3} else {print $1}}' | sort -u); do
	test -e "$F" && copy_deps "$F"
    done
}

copy_deps "$1"
