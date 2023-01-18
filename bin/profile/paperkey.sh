#!/bin/sh
# https://www.jabberwocky.com/software/paperkey/

paperkey_print() {
    for FILE; do
        lp -o media=a4 -o page-bottom=10 -o page-left=15 -o page-right=10 -o page-top=10 -o sides=two-sided-long-edge "$FILE"
    done
}

paperkey_print_all() {
    echo "Print both paperkey of GPG secret keys + public keys as armoured ASCII"
    paperkey_print *.paperkey *.pub.asc
}

# paperkey --secret-key my-secret-key.gpg --output to-be-printed.txt
paperkey_backup() {
    for FILE; do
        paperkey --secret-key "$FILE" --output "${FILE%.*}.paperkey"
    done
}

# paperkey --pubring my-public-key.gpg --secrets my-key-text-file.txt --output my-secret-key.gpg
paperkey_restore() {
    for FILE; do
        paperkey --pubring "${FILE%.*}.pub.gpg" --secrets "${FILE%.*}.paperkey" --output "${FILE%.*}.sec.gpg"
    done
}

# Main
if [ $# -ge 1 ]; then
    CMD="${1##paperkey_}"
    shift
    paperkey_$CMD "$@"
fi
