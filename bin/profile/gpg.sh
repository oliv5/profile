#!/bin/sh
#
# Filename: gpg.sh
# Initial date: 2012/11/31
# Licence: GNU GPL
# Dependency: gpg
# optional: zenity, wipe
# Author: Oliv5 <oliv5@caramail.com>

# Variables
VERSION=0.99
PASSPHRASE=""
RECIPIENT=""
NB_ENCRYPT=0
NB_DECRYPT=0
NB_FAILED=0
GPG_VERSION=$(gpg --version | cut -f3 -d' ' | awk -F'.' '{printf "%.d%.2d%.2d",$1,$2,$3; exit}')
GPG_VERSION_2_2_4=20204

# Options
EN_ENCRYPT=1
EN_DECRYPT=1
EN_AUTODETECT=1
EN_SIGN=""
EN_SYMMETRIC=""
EN_BATCH_RUN=1
PUB_KEYS=""
DELETE=1
SIMULATE=""
OVERWRITE=""
VERBOSE="false"
STDOUT="/dev/null"

# Autodetect zenity & display
ZENITY=""
xhost +si:localuser:$(whoami) >/dev/null 2>&1 && {
  which zenity >/dev/null && ZENITY=1
}

# Get command line options
while getopts egdhk:pfsouvz OPTNAME
do case "$OPTNAME" in
  e)  EN_DECRYPT=""; EN_AUTODETECT="";;
  d)  EN_ENCRYPT=""; EN_AUTODETECT="";;
  g)  EN_SIGN=1; EN_SYMMETRIC="";;
  h)  EN_SYMMETRIC=1; EN_SIGN="";;
  k)  RECIPIENT="$OPTARG";;
  p)  PUB_KEYS=1;;
  f)  DELETE=""; echo "Keeping input files." >"$STDOUT";;
  s)  SIMULATE="true"; echo "Performing a dry-run with no file changed." >"$STDOUT";;
  o)  OVERWRITE="--yes";;
  u)  EN_BATCH_RUN="";;
  v)  VERBOSE=""; STDOUT="/dev/stdout";;
  z)  ZENITY="";;
  [?]) echo >&2 "Usage: $(basename $0) v$VERSION [-e] [-g] [-d] [-k key] [-p] [-f] [-s] [-v] [-z]  ... directories/files"
       echo >&2 "-e    (e)ncrypt only"
       echo >&2 "-g    si(g)n (with -e only)"
       echo >&2 "-d    (d)ecrypt only"
       echo >&2 "-k    select recipent (k)ey"
       echo >&2 "-p    list (p)ublic keys instead of secret keys"
       echo >&2 "-h    symmetric operation (passphrase only)"
       echo >&2 "-f    do not delete input (f)iles"
       echo >&2 "-s    (s)imulate"
       echo >&2 "-o    (o)verwrite output file"
       echo >&2 "-v    (v)erbose"
       echo >&2 "-u    disable batch r(u)n; different recipients/passphrases for all files"
       echo >&2 "-z    no (z)enity"
       exit 1;;
  esac
done
shift $(expr $OPTIND - 1)

# Display a piece of information
DisplayInfo() {
  if [ -z "$ZENITY" ]; then
    echo "$1"
    echo "$2"
  else
    zenity --info --title "$1" --text "$2" --timeout 10
  fi
}

# Display a warning
DisplayWarning() {
  if [ -z "$ZENITY" ]; then
    echo "$1"
    echo "$2"
  else
    zenity --warning --title "$1" --text "$2" --timeout 10
  fi
}

# Display a question
DisplayQuestion() {
  if [ -z "$ZENITY" ]; then
    IFS="$(printf '\n')"
    #read -s -t 30 -p "$2 " ANSWER
    read -p "$2 " ANSWER </dev/tty
    echo $ANSWER
  else
    #echo $(zenity --title "$1" --entry --hide-text --text="$2" --timeout 30 | sed 's/^[ \t]*//;s/[ \t]*$//')
    echo $(zenity --title "$1" --entry --hide-text --text="$2" | sed 's/^[ \t]*//;s/[ \t]*$//')
  fi
}

# Display a list of choices, get selection
DisplayList() {
  local TITLE="$1"
  local DESCR="$2"
  local HEADER1="$3"
  local HEADER2="$4"
  shift 4
  if [ -z "$ZENITY" ]; then
    echo "$TITLE" >/dev/stderr
    echo "$@" >/dev/stderr
    #read -t 30 -p "$DESCR " ANSWER
    read -p "$DESCR " ANSWER </dev/tty
    echo $ANSWER
  else
    #zenity --list --radiolist --timeout 30 --title "$TITLE" --text "$DESCR" --column "$HEADER1" --column "$HEADER2" "$@"
    zenity --list --radiolist --title "$TITLE" --text "$DESCR" --column "$HEADER1" --column "$HEADER2" "$@"
  fi
}

GetRecipient() {
    local IFS=":"
    # List the available keys
    if [ $GPG_VERSION -ge $GPG_VERSION_2_2_4 ]; then
      if [ -n "$PUB_KEYS" ]; then
        set -- $(gpg --list-keys --with-colons | awk -F: 'BEGIN{num=0} /uid/{num++;printf "%s:%s:",(num==1)?"TRUE":"",$10}')
      else
        set -- $(gpg --list-secret-keys --with-colons | awk -F: 'BEGIN{num=0} /uid/{num++;printf "%s:%s:",(num==1)?"TRUE":"",$10}')
      fi
    else
      if [ -n "$PUB_KEYS" ]; then
        set -- $(gpg --list-keys --with-colons | awk -F: 'BEGIN{num=0} /pub/{num++;printf "%s:%s:",(num==1)?"TRUE":"",$10}')
      else
        set -- $(gpg --list-secret-keys --with-colons | awk -F: 'BEGIN{num=0} /sec/{num++;printf "%s:%s:",(num==1)?"TRUE":"",$10}')
      fi
    fi
    DisplayList "Encryption Keys" "Select the encryption key:" "*" "Available keys:" "$@"
}

DeleteFiles() {
  for FILES; do
    $VERBOSE echo "Delete input file '$FILE'"
    if command -v wipe >/dev/null && [ ! -L "$FILE" ] && [ $(stat -c %s "$FILE") -lt 25000000 ]; then
      $SIMULATE wipe -D -q -f "$FILE"
    else
      $SIMULATE rm -v "$FILE"
    fi
  done
}

# Decrypt file
Decrypt(){
  local INPUT="$1"
  local OUTPUT="${INPUT%.gpg}"
  if [ "$OUTPUT" = "$INPUT" ]; then
    OUTPUT="${OUTPUT}.out"
  fi
  echo "Decrypting file '$INPUT' into '$OUTPUT'"

  # Collect passphrase
  if [ -n "$EN_BATCH_RUN" ] && [ -z "$PASSPHRASE" ]; then
    PASSPHRASE="$(DisplayQuestion "Decryption" "Enter your decryption passphrase:")"
    if [ -z "$PASSPHRASE" ]; then
      $VERBOSE DisplayWarning "No passphrase" "Decryption is disabled!"
      unset EN_DECRYPT
      return
    fi
  fi

  # Decrypt
  echo "$PASSPHRASE" | $SIMULATE gpg -v --batch $OVERWRITE ${PASSPHRASE:+--passphrase-fd} ${PASSPHRASE:+0} --decrypt -o "$OUTPUT" "$INPUT"

  # One more file!
  if [ -f "$OUTPUT" ]; then
    NB_DECRYPT=$(($NB_DECRYPT+1))
  else
    NB_FAILED=$(($NB_FAILED+1))
  fi

  # Delete original file if new one is present
  if [ ! -z "$DELETE" -a -f "$OUTPUT" ]; then
    DeleteFiles "$INPUT"
  fi
}

#Encrypt file
Encrypt() {
  local INPUT="$1"
  local OUTPUT="${INPUT}.gpg"
  echo "Encrypting file '$INPUT' into '$OUTPUT'"

  # Encrypt
  if [ -n "$EN_SYMMETRIC" ]; then

    $VERBOSE echo "Symmetric encryption"

    if [ -n "$EN_BATCH_RUN" ] && [ -z "$PASSPHRASE" ]; then
      local PASSPHRASE1="---"
      local PASSPHRASE2="N/A"
      while [ "$PASSPHRASE1" != "$PASSPHRASE2" ]; do
        PASSPHRASE1="$(DisplayQuestion "Signature" "Enter your encryption passphrase (1/2)")"
        if [ -z "$PASSPHRASE1" ]; then
          $VERBOSE DisplayWarning "Empty passphrase" "Abort encryption!"
          unset EN_AUTODETECT
          unset EN_ENCRYPT
          return
        fi
        PASSPHRASE2="$(DisplayQuestion "Signature" "Repeat your encryption passphrase (2/2)")"
      done
      PASSPHRASE="$PASSPHRASE1"
    fi

    echo "$PASSPHRASE" | $SIMULATE gpg -v --batch $OVERWRITE ${PASSPHRASE:+--passphrase-fd} ${PASSPHRASE:+0} --symmetric -o "$OUTPUT" "$INPUT"

  else

    $VERBOSE echo "Asymmetric encryption"

    if [ -n "$EN_BATCH_RUN" ] && [ -z "$RECIPIENT" ]; then
      RECIPIENT="$(GetRecipient)"
      if [ -z "$RECIPIENT" ]; then
        $VERBOSE DisplayWarning "No key" "Abort encryption!"
        unset EN_AUTODETECT
        unset EN_ENCRYPT
        return
      fi
    fi

    $VERBOSE echo "Recipient $RECIPIENT"
    $SIMULATE gpg -v --batch $OVERWRITE --no-default-recipient ${RECIPIENT:+--recipient} ${RECIPIENT:+"$RECIPIENT"} --trust-model always --encrypt ${EN_SIGN:+--sign} -o "$OUTPUT" "$INPUT"
  fi

  # One more file!
  if [ -f "$OUTPUT" ]; then
    NB_ENCRYPT=$(($NB_ENCRYPT+1))
  else
    NB_FAILED=$(($NB_FAILED+1))
  fi

  # Delete original file if new one is present
  if [ ! -z "$DELETE" -a -f "$OUTPUT" ]; then
    DeleteFiles "$INPUT"
  fi
}

# Main
true ${@:?No file/directory specified...}
IFS='
'
# Loop through nautilus files or command line files
NAUTILUS_SCRIPT_SELECTED_FILE_PATHS="$(printf %s "$NAUTILUS_SCRIPT_SELECTED_FILE_PATHS" | sed -e 's/\n$//')"
set -- "${@:-$NAUTILUS_SCRIPT_SELECTED_FILE_PATHS}"
for SRC; do
  for FILE in $(find "$SRC" ! -type d); do
    if [ -n "$EN_AUTODETECT" ]; then
      if echo "$FILE" | grep -E "\.(gpg|pgp)$" >/dev/null 2>&1; then
        unset EN_ENCRYPT # cancel encryption
      else
        unset EN_DECRYPT # cancel decryption
      fi
    fi
    if [ -n "$EN_DECRYPT" ]; then
      Decrypt "$FILE" >"$STDOUT" 2>&1
    elif [ -n "$EN_ENCRYPT" ]; then
      Encrypt "$FILE" >"$STDOUT" 2>&1
    fi
  done
done

# Exit status
$VERBOSE DisplayInfo "Job complete!" "Encrypted files: $NB_ENCRYPT\nDecrypted files: $NB_DECRYPT\nFailed files: $NB_FAILED"
exit 0
