#!/bin/sh
PROG="${1:?No program to run...}"
shift

echo >&2 "Reminder: the program may require to be linked statically in order to use breakpoints with qemu!"
echo >&2

# Run the program with qemu in docker and wait for gdb commands on port 1234
qemu-aarch64 -g 1234 -L /usr/aarch64-linux-gnu "$PROG" &>/dev/stdout </dev/stdin &

sleep 1

# Run gdb-multiarch and connect on port 1234
gdb-multiarch -q --nh \
    -ex "file \"$PROG\"" \
    -ex 'set architecture aarch64' \
    -ex 'target remote localhost:1234' \
    -ex 'set sysroot /usr/aarch64-linux-gnu' \
    -ex 'set solib-search-path /usr/aarch64-linux-gnu/lib' \
    -ex 'set breakpoint pending on' \
    "$@"
