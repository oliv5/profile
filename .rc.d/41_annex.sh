#!/bin/sh

# Get annex version
annex_version() {
  echo "${1:-${ANNEX_VERSION:-$(git annex version 2>/dev/null | awk -F': ' '/git-annex version:/ {print $2}')}}" | awk -F'.' '{printf "%.d%.8d\n",$1,$2$3$4}'
}
annex_repo_version() {
  git config --get annex.version 2>/dev/null || echo 0
}

# Check annex exists
annex_exists() {
  git ${1:+--git-dir="$1"} config --get annex.version >/dev/null 2>&1
}

# Check annex has been modified
annex_modified() {
  test ! -z "$(git ${1:+--git-dir="$1"} annex status)"
}

# Test annex direct-mode
annex_direct() {
  [ "$(git ${1:+--git-dir="$1"} config --get annex.direct)" = "true" ]
}

# Test annex bare
annex_bare() {
  annex_exists "$@" && ! annex_direct "$@" && git_bare "$@"
}

# Test annex standard (indirect, not bare)
annex_std() {
  annex_exists "$@" && ! annex_direct "$@" && ! git_bare "$@"
}

# Get root dir
annex_root() {
  annex_direct "$@" && readlink -f "$(git_root "$@")/.." || git_root "$@"
}

########################################
# Init annex
annex_init() {
  git_exists "${1:-.}" || git init "${1:-.}"
  git ${1:+--git-dir="${1:-.}/.git"} annex init "${2:-$(uname -n)}"
}

# Init annex bare repo
annex_init_bare() {
  git init --bare "${1:-.}" && git --git-dir="${1:-.}" annex init "${2:-$(uname -n)}"
}

# Uninit annex
annex_uninit() {
  git --git-dir="${1:-.}" annex uninit && 
  git --git-dir="${1:-.}" config --replace-all core.bare false
}

########################################
# Annex config - these parameters are stored in the annex for all repos to see them
annex_config_set() { git annex config --set "$@"; }
annex_config_rm() { git annex config --unset "$1"; }
annex_config_set_remotes() { local REMOTE; for REMOTE in $(git_remotes "$1"); do git annex config --set "remote.$REMOTE.$2" "$3"; done; }
annex_config_rm_remotes() { local REMOTE; for REMOTE in $(git_remotes "$1"); do git annex config --unset "remote.$REMOTE.$2"; done; }

########################################

# Setup v7 annex in dual mode: plain & annexed files
# https://git-annex.branchable.com/git-annex/
# https://git-annex.branchable.com/tips/largefiles/
# https://git-annex.branchable.com/forum/Annex_v7_repos_and_plain_git_files/
# https://git-annex.branchable.com/forum/lets_discuss_git_add_behavior/#comment-37e0ecaf8e0f763229fd7b8ee9b5a577
annex_mixed_content() {
  local SIZE="${1:-nothing}"
  if [ "$SIZE" = "remove" ] || [ "$SIZE" = "rm" ]; then
    git_config_rm annex.gitaddtoannex
    git_config_rm annex.addsmallfiles
    git_config_rm annex.largefiles
  elif [ "$SIZE" = "anything" ] || [ "$SIZE" = "all" ]; then
    git_config_set annex.gitaddtoannex "true"
    git_config_set annex.addsmallfiles "true"
    git_config_set annex.largefiles "anything"
  elif [ "$SIZE" = "nothing" ] || [ "$SIZE" = "none" ]; then
    git_config_set annex.gitaddtoannex "false"
    git_config_set annex.addsmallfiles "false"
    #git_config_set annex.largefiles "nothing"
    git_config_rm annex.largefiles
  else
    git_config_set annex.gitaddtoannex "false"
    git_config_set annex.addsmallfiles "false"
    git_config_set annex.largefiles "$SIZE"
  fi
}

########################################
# Limitations
annex_autocommit() {
  if [ -z "$1" ]; then
    git config --get annex.autocommit
  else
    git config --replace-all annex.autocommit "$1"
  fi
}

annex_remote_push_enable() {
  :${1:?no remote specified...}
  if [ -z "$2" ]; then
    git config --get "remote.$1.annex-push"
  else
    git config --replace-all "remote.$1.annex-push" "$2"
  fi
}

annex_remote_pull_enable() {
  :${1:?no remote specified...}
  if [ -z "$2" ]; then
    git config --get "remote.$1.annex-pull"
  else
    git config --replace-all "remote.$1.annex-pull" "$2"
  fi
}

annex_remote_sync_enable() {
  :${1:?no remote specified...}
  if [ -z "$2" ]; then
    git config --get "remote.$1.annex-sync"
  else
    git config --replace-all "remote.$1.annex-sync" "$2"
  fi
}

annex_remote_ignore() {
  :${1:?no remote specified...}
  if [ -z "$2" ]; then
    git config --get "remote.$1.annex-ignore"
  else
    git config --replace-all "remote.$1.annex-ignore" "$2"
  fi
}

annex_remote_readonly() {
  :${1:?no remote specified...}
  if [ -z "$2" ]; then
    git config --get "remote.$1.annex-readonly"
  else
    git config --replace-all "remote.$1.annex-readonly" "$2"
  fi
}

########################################
# Init hubic annex
annex_init_hubic() {
  local NAME="${1:?No remote name specified...}"
  local REMOTEPATH="${2:-$(git_repo)}"
  local ENCRYPTION="${3:-none}"
  local KEYID="$4"
  local CHUNKS="$5"
  _run() { echo "$@"; "$@"; }
  _run git annex enableremote "$NAME" encryption="$ENCRYPTION" type=external externaltype=hubic hubic_container=annex hubic_path="$REMOTEPATH" embedcreds=no ${CHUNKS:+chunk="$CHUNKS"} ${KEYID:+keyid="$KEYID"} 2>/dev/null ||
  _run git annex initremote   "$NAME" encryption="$ENCRYPTION" type=external externaltype=hubic hubic_container=annex hubic_path="$REMOTEPATH" embedcreds=no ${CHUNKS:+chunk="$CHUNKS"} ${KEYID:+keyid="$KEYID"}
}

# Init gdrive annex
annex_init_gdrive() {
  local NAME="${1:?No remote name specified...}"
  local REMOTEPATH="${2:-$(git_repo)}"
  local ENCRYPTION="${3:-none}"
  local KEYID="$4"
  local CHUNKS="$5"
  _run() { echo "$@"; "$@"; }
  _run git annex enableremote "$NAME" encryption="$ENCRYPTION" type=external externaltype=googledrive folder="$REMOTEPATH" ${CHUNKS:+chunk="$CHUNKS"} ${KEYID:+keyid="$KEYID"} 2>/dev/null ||
  _run git annex initremote   "$NAME" encryption="$ENCRYPTION" type=external externaltype=googledrive folder="$REMOTEPATH" ${CHUNKS:+chunk="$CHUNKS"} ${KEYID:+keyid="$KEYID"}
}

# Init bup annex
annex_init_bup() {
  local NAME="${1:?No remote name specified...}"
  local REMOTEPATH="${2:-$(git_repo)}"
  local ENCRYPTION="${3:-none}"
  local KEYID="$4"
  local CHUNKS="$5"
  _run() { echo "$@"; "$@"; }
  _run git annex enableremote "$NAME" encryption="$ENCRYPTION" type=bup buprepo="$REMOTEPATH" ${CHUNKS:+chunk="$CHUNKS"} ${KEYID:+keyid="$KEYID"} 2>/dev/null ||
  _run git annex initremote   "$NAME" encryption="$ENCRYPTION" type=bup buprepo="$REMOTEPATH" ${CHUNKS:+chunk="$CHUNKS"} ${KEYID:+keyid="$KEYID"}
}

# Init rsync annex
annex_init_rsync() {
  local NAME="${1:?No remote name specified...}"
  local REMOTEPATH="${2:-$(git_repo)}"
  local ENCRYPTION="${3:-none}"
  local KEYID="$4"
  local CHUNKS="$5"
  _run() { echo "$@"; "$@"; }
  _run git annex enableremote "$NAME" encryption="$ENCRYPTION" type=rsync rsyncurl="$REMOTEPATH" ${CHUNKS:+chunk="$CHUNKS"} ${KEYID:+keyid="$KEYID"} 2>/dev/null ||
  _run git annex initremote   "$NAME" encryption="$ENCRYPTION" type=rsync rsyncurl="$REMOTEPATH" ${CHUNKS:+chunk="$CHUNKS"} ${KEYID:+keyid="$KEYID"}
}

# Init directory annex
annex_init_directory() {
  local NAME="${1:?No remote name specified...}"
  local REMOTEPATH="${2:-$(git_repo)}"
  local ENCRYPTION="${3:-none}"
  local KEYID="$4"
  local CHUNKS="$5"
  local EXPORTTREE="$6"
  local IMPORTTREE="$7"
  _run() { echo "$@"; "$@"; }
  _run git annex enableremote "$NAME" encryption="$ENCRYPTION" type=directory directory="$REMOTEPATH" ${CHUNKS:+chunk="$CHUNKS"} ${KEYID:+keyid="$KEYID"} ${EXPORTTREE:+exporttree="$EXPORTTREE"} ${IMPORTTREE:+importtree="$IMPORTTREE"} 2>/dev/null ||
  _run git annex initremote   "$NAME" encryption="$ENCRYPTION" type=directory directory="$REMOTEPATH" ${CHUNKS:+chunk="$CHUNKS"} ${KEYID:+keyid="$KEYID"} ${EXPORTTREE:+exporttree="$EXPORTTREE"} ${IMPORTTREE:+importtree="$IMPORTTREE"}
}

# Init gcrypt annex
annex_init_gcrypt() {
  local NAME="${1:?No remote name specified...}"
  local REMOTEPATH="${2:-$(git_repo)}"
  local ENCRYPTION="${3:-none}"
  local KEYID="$4"
  local CHUNKS="$5"
  _run() { echo "$@"; "$@"; }
  _run git annex enableremote "$NAME" encryption="$ENCRYPTION" type=gcrypt gitrepo="$REMOTEPATH" ${CHUNKS:+chunk="$CHUNKS"} ${KEYID:+keyid="$KEYID"} 2>/dev/null ||
  _run git annex initremote   "$NAME" encryption="$ENCRYPTION" type=gcrypt gitrepo="$REMOTEPATH" ${CHUNKS:+chunk="$CHUNKS"} ${KEYID:+keyid="$KEYID"}
}

# Clone gcrypt annex
annex_clone_gcrypt() {
  local NAME="${1:?No remote name specified...}"
  local REMOTEPATH="${2:-$(git_repo)}"
  ! git-remote-gcrypt --check "$REMOTEPATH" && return 1
  _run() { echo "$@"; "$@"; }
  _run git clone "gcrypt::$REMOTEPATH" "$NAME" &&
    _run git annex enableremote "$NAME" type=gcrypt gitrepo="$REMOTEPATH"
}

# Init rclone annex
annex_init_rclone() {
  local NAME="${1:?No remote name specified...}"
  local REMOTEPATH="${2:-$(git_repo)}"
  local ENCRYPTION="${3:-none}"
  local KEYID="$4"
  local CHUNKS="$5"
  local PROFILE="${6:-$NAME}"
  local MAC="${7:-HMACSHA512}"
  local LAYOUT="${8:-lower}"
  _run() { echo "$@"; "$@"; }
  _run git annex enableremote "$NAME" encryption="$ENCRYPTION" type=external externaltype=rclone target="$PROFILE" prefix="$REMOTEPATH" ${CHUNKS:+chunk="$CHUNKS"} mac="${MAC}" rclone_layout="$LAYOUT" ${KEYID:+keyid="$KEYID"} ||
  _run git annex initremote "$NAME" encryption="$ENCRYPTION" type=external externaltype=rclone target="$PROFILE" prefix="$REMOTEPATH" ${CHUNKS:+chunk="$CHUNKS"} mac="${MAC}" rclone_layout="$LAYOUT" ${KEYID:+keyid="$KEYID"}
}

########################################
# Git status for scripts
annex_st() {
  git annex status | awk -F'#;#.' '/^[\? ]?'$1'[\? ]?/ {sub(/ /,"#;#.");print $2}'
}

########################################
# Check if inputs are all uuids
annex_isuuid() {
  echo "$*" | sed 's/-//g' | command grep -E '^(\s?[a-zA-Z0-9]{32}\s?)+$' >/dev/null || return 1
  return 0
}

# Get local uuid
annex_uuid() {
  [ $# -eq 0 ] && git config annex.uuid
}

####
# List remotes by name or uuid
annex_uuids() {
  local PATTERN
  {
    PATTERN=""; for REMOTE in "${@:-.*}"; do PATTERN="${PATTERN:+$PATTERN|}^$REMOTE\$"; done
    { git show git-annex:uuid.log 2>/dev/null; cat .git/annex/journal/uuid.log 2>/dev/null; } |
      awk -v pattern="$PATTERN" 'NF==3 && ($1~pattern || $2~pattern) {print $1}'
    PATTERN=""; for REMOTE in "$@"; do PATTERN="${PATTERN:+$PATTERN }$REMOTE"; done
    git annex info --fast --json $PATTERN 2>/dev/null | jq -Sr '.uuid | select(. != null)' 2>/dev/null
  } | sort -u
  # Warning: `git annex info` does not print dead remotes
  #~ PATTERN=""; for REMOTE in "${@:-.*}"; do PATTERN="${PATTERN:+$PATTERN|}\[?$REMOTE\]?"; done
  #~ git annex info "$@" --fast --json | jq -r --arg PATTERN "$PATTERN" '
    #~ (."semitrusted repositories"[] , ."untrusted repositories"[] , ."trusted repositories"[])? // . |
    #~ select(.uuid | test($PATTERN)) // select(.description | test($PATTERN)) |
    #~ select(.uuid | test("00000000-0000-0000-0000-00000000000.") | not) |
    #~ .uuid
  #~ '
}
annex_remotes() {
  local PATTERN
  { 
    PATTERN=""; for REMOTE in "${@:-.*}"; do PATTERN="${PATTERN:+$PATTERN|}^$REMOTE\$"; done
    { git show git-annex:uuid.log 2>/dev/null; cat .git/annex/journal/uuid.log 2>/dev/null; } |
    awk -v pattern="$PATTERN" 'NF==3 && ($1~pattern || $2~pattern) {print $2}'
    # Warning: `git annex info` does not print dead remotes
    PATTERN=""; for REMOTE in "$@"; do PATTERN="${PATTERN:+$PATTERN }$REMOTE"; done
    git annex info --fast --json $PATTERN 2>/dev/null | jq -Sr '.remote | select(. != null)' 2>/dev/null
  } | sort -u
  # Warning: `git annex info` does not print dead remotes
  #~ PATTERN=""; for REMOTE in "${@:-.*}"; do PATTERN="${PATTERN:+$PATTERN|}\[?$REMOTE\]?"; done
  #~ git annex info --fast --json | jq -r --arg PATTERN "$PATTERN" '
    #~ (."semitrusted repositories"[] , ."untrusted repositories"[] , ."trusted repositories"[])? // . |
    #~ select(.uuid | test($PATTERN)) // select(.description | test($PATTERN)) |
    #~ select(.uuid | test("00000000-0000-0000-0000-00000000000.") | not) |
    #~ .description | gsub("\\[|\\]";"")
  #~ '
}

####
# List dead remotes
annex_dead() {
  local UUIDS="$(annex_uuids "$@" | tr '\n' '|' | rev | cut -c2- | rev)"
  { git show git-annex:trust.log 2>/dev/null; cat .git/annex/journal/trust.log 2>/dev/null; } |
    sed -r 's/^(.*)timestamp=(.*)s$/\2 \1/' | sort -k2b,2 -k1,1rn |
    awk -v uuids="${UUIDS:-^$}" '$2~uuids && done[$2]=="" { done[$2]=1; if ($3~/X/) {print $2} }' |
    sort -u
}
annex_notdead() {
  # note: reverse logic because trust.log does not contain a repo whose trust level was never set
  local UUIDS="$(annex_dead | tr '\n' '|' | rev | cut -c2- | rev)"
  annex_uuids "$@" |
    command grep -vE "${UUIDS:-^$}" |
    sort -u
}
# Check one of the (listed) remotes is dead
annex_isdead() {
  [ -n "$(annex_dead "$@")" ]
}

####
# List special remotes
annex_special() {
  local UUIDS="$(annex_uuids "$@" | tr '\n' '|' | rev | cut -c2- | rev)"
  { git show git-annex:remote.log 2>/dev/null; cat .git/annex/journal/remote.log 2>/dev/null; } |
    sed -r 's/^(.*)timestamp=(.*)s$/\2 \1/' | sort -k2b,2 -k1,1rn |
    awk -v uuids="${UUIDS:-^$}" '$2~uuids {print $2}' |
    sort -u
}
annex_notspecial() {
  # note: reverse logic because trust.log does not contain a repo whose trust level was never set
  local UUIDS="$(annex_special | tr '\n' '|' | rev | cut -c2- | rev)"
  annex_uuids "$@" |
    command grep -vE "${UUIDS:-^$}" |
    sort -u
}
# Check one of the (listed) remotes is  special
annex_isspecial() {
  [ -n "$(annex_special "$@")" ]
}

####
# List enabled local remotes
annex_enabled() {
  local UUIDS="$(annex_uuids "$@" | tr '\n' '|' | rev | cut -c2- | rev)"
  local EXCLUDE="$(git config --get-regexp "remote\..*\.annex-ignore" true | awk -F. '{printf $2"|"}' | sed -e "s/|$//")"
  git config --get-regexp "remote\..*\.annex-uuid" |
    awk -v uuids="${UUIDS:-^$}" -v excluded="${EXCLUDE:-^$}" '$1!~excluded && $2~uuids {print $2}' |
    sort -u
}
alias annex_disabled='annex_notenabled'
annex_notenabled() {
  # note: reverse logic because trust.log does not contain a repo whose trust level was never set
  local UUIDS="$(annex_enabled | tr '\n' '|' | rev | cut -c2- | rev)"
  annex_uuids "$@" |
    command grep -vE "${UUIDS:-^$}" |
    sort -u
}
# Check one of the (listed) remotes is enabled
annex_isenabled() {
  [ -n "$(annex_enabled "$@")" ]
}

####
# List exported annexes
annex_exported() {
  local UUIDS="$(annex_uuids "$@" | tr '\n' '|' | rev | cut -c2- | rev)"
  { git show git-annex:remote.log 2>/dev/null; cat .git/annex/journal/remote.log 2>/dev/null; } |
    sed -r 's/^(.*)timestamp=(.*)s$/\2 \1/' | sort -k2b,2 -k1,1rn |
    awk -v uuids="${UUIDS:-^$}" '$2~uuids && done[$2]=="" { done[$2]=1; if ($0~/exporttree=yes/) {print $2} }' |
    sort -u
}
annex_notexported() {
  # note: reverse logic because trust.log does not contain a repo whose trust level was never set
  local UUIDS="$(annex_exported | tr '\n' '|' | rev | cut -c2- | rev)"
  annex_uuids "$@" |
    command grep -vE "${UUIDS:-^$}" |
    sort -u
}
# Check one of the (listed) remotes is exported
annex_isexported() {
  [ -n "$(annex_exported "$@")" ]
}

####
# List annex url or path of some enabled remotes
annex_path() {
  local REMOTES="$(annex_remotes "$@" | tr '\n' '|' | rev | cut -c2- | rev)"
  git config -l | grep -oE "remote.($REMOTES).(url|annex-rsyncurl|annex-directory)=.*" | sed 's/.*=//'
}

####
# List online annexes
annex_online() {
  for REMOTE in $(annex_remotes "$@"); do
    local P="$(annex_path "$REMOTE")"
    test -e "$P" || git ls-remote -q "$P" >/dev/null 2>&1 && echo "$REMOTE"
  done
}
alias annex_offline='annex_notonline'
annex_notonline() {
  for REMOTE in $(annex_remotes "$@"); do
    local P="$(annex_path "$REMOTE")"
    ! test -e "$P" && ! git ls-remote -q "$P" >/dev/null 2>&1 && echo "$REMOTE"
  done
}
annex_isonline() {
  [ -n "$(annex_online "$@")" ]
}

########################################
annex_hook_commit() {
  local HOOK="$(git_dir)/hooks/pre-commit"
  [ -e "$HOOK" ] && { echo "Hook file $HOOK exists already..."; return 1; }
  cat > "$HOOK" <<EOF
#!/bin/sh
# automatically configured by git-annex
git annex pre-commit .

# Go though added files (--diff-filter=A) and check whether they are symlinks (test -h)
git diff --cached --name-only --diff-filter=A -z |
    xargs -r -0 -- sh -c '
        for F; do
            test ! -h "\$F" && echo "File \"\$F\" is not a symlink. Abort..." && exit 1
        done
    ' _
EOF
  chmod +x "$HOOK"
}

########################################
# Print annex infos (inc. encryption ciphers)
annex_getinfo() {
  git annex info .
  git show git-annex:remote.log
  for UUID in $(annex_notdead "$@"); do
    echo '-------------------------'
    git annex info "$UUID"
  done
}

# Lookup keys of a single special remote
annex_lookup_special_remote() {
  local UUID="${1:?No UUID specified...}"
  shift 1
  # Preambles
  git_exists || return 1
  annex_std || return 2
  annex_isuuid "$UUID" || return 3
  annex_isspecial "$UUID" || return 4
  # Bash lookup_key
  bash_lookup_key() {
    bash -c '
      # Decrypt cipher
      decrypt_cipher() {
        cipher="$1"
        echo "$(echo -n "$cipher" | base64 -d | gpg --decrypt --quiet)"
      }
      # Encrypt git-annex key
      encrypt_key() {
        local key="$1"
        local cipher="$2"
        local mac="$3"
        local enckey="$key"
        if [ -n "$cipher" ]; then
          enckey="GPG$mac--$(echo -n "$key" | openssl dgst -${mac#HMAC} -hmac "$cipher" | sed "s/(stdin)= //")"
        fi
        local checksum="$(echo -n $enckey | md5sum)"
        echo "${checksum:0:3}/${checksum:3:3}/$enckey"
      }
      # Find the special remote key from the local key
      lookup_key() {
        local encryption="$1"
        local cipher="$2"
        local mac="$3"
        local remote_uuid="$4"
        local file="$(readlink -m "$5")"
        # No file
        if [ -z "$file" ]; then
          echo >&2 "File \"$5\" does not exist..."
          exit 1
        fi
        # Analyse keys
        local annex_key="$(basename "$file")"
        local checksum="$(echo -n "$annex_key" | md5sum)"
        local branchdir="${checksum:0:3}/${checksum:3:3}"
        if [ "$(git config annex.tune.branchhash1)" = "true" ]; then
            branchdir="${branchdir%%/*}"
        fi
        local chunklog="$(git show "git-annex:$branchdir/$annex_key.log.cnk" 2>/dev/null | grep $remote_uuid: | grep -v " 0$")"
        local chunklog_lc="$(echo "$chunklog" | wc -l)"
        local chunksize numchunks chunk_key line n
        # Decrypt cipher
        if [ "$encryption" = "hybrid" ] || [ "$encryption" = "pubkey" ]; then
            cipher="$(decrypt_cipher "$cipher")"
        fi
        # Pull out MAC cipher from beginning of cipher
        if [ "$encryption" = "hybrid" ] ; then
            cipher="$(echo -n "$cipher" | head  -c 256 )"
        elif [ "$encryption" = "shared" ] ; then
            cipher="$(echo -n "$cipher" | base64 -d | tr -d "\n" | head  -c 256 )"
        elif [ "$encryption" = "pubkey" ] ; then
            # pubkey cipher includes a trailing newline which was stripped in
            # decrypt_cipher process substitution step above
            #IFS= read -rd '' cipher < <( printf "$cipher\n" )
            cipher="$cipher
"
        elif [ "$encryption" = "sharedpubkey" ] ; then
            # Full cipher is base64 decoded. Add a trailing \n lost by the shell somewhere
            cipher="$(echo -n "$cipher" | base64 -d)
"
        fi
        if [ -z "$chunklog" ]; then
            echo "# non-chunked" >&2
            encrypt_key "$annex_key" "$cipher" "$mac"
        elif [ "$chunklog_lc" -ge 1 ]; then
            if [ "$chunklog_lc" -ge 2 ]; then
                echo "INFO: the remote seems to have multiple sets of chunks" >&2
            fi
            echo "$chunklog" | while read -r line; do
                chunksize="$(echo -n "${line#*:}" | cut -d " " -f 1)"
                numchunks="$(echo -n "${line#*:}" | cut -d " " -f 2)"
                echo "# $numchunks chunks of $chunksize bytes" >&2
                for n in $(seq 1 $numchunks); do
                    chunk_key="${annex_key/--/-S$chunksize-C$n--}"
                    encrypt_key "$chunk_key" "$cipher" "$mac"
                done
            done
        fi
      }
      # Main call
      lookup_key "$@"
    ' _ "$@"
  }
  # Main variables
  local REMOTE_CONFIG="$(git show git-annex:remote.log | grep "^$UUID" | head -n 1)"
  local ENCRYPTION="$(echo "$REMOTE_CONFIG" | grep -oP 'encryption\=.*? ' | tr -d ' \n' | sed 's/encryption=//')"
  local CIPHER="$(echo "$REMOTE_CONFIG" | grep -oP 'cipher\=.*? ' | tr -d ' \n' | sed 's/cipher=//')"
  local REMOTE="$(echo "$REMOTE_CONFIG" | grep -oP 'name\=.*? ' | tr -d ' \n' | sed 's/name=//')"
  local MAC="$(echo "$REMOTE_CONFIG" | grep -oP 'mac\=.*? ' | tr -d ' \n' | sed 's/mac=//')"
  [ -z "$REMOTE_CONFIG" ] && { echo >&2 "UUID '$UUID' config not found..."; return 10; }
  [ -z "$ENCRYPTION" ] && { echo >&2 "UUID '$UUID' encryption not found..."; return 10; }
  [ -z "$CIPHER" -a "$ENCRYPTION" != "none" ] && { echo >&2 "UUID '$UUID' cipher not found..."; return 10; }
  [ -z "$REMOTE" ] && { echo >&2 "UUID '$UUID' remote name not found..."; return 10; }
  [ -z "$MAC" ] && MAC=HMACSHA1
  # Main processing
  echo "## Uuid $UUID"
  echo "## Remote $REMOTE"
  echo "## Encryption $ENCRYPTION"
  echo "## Cipher $CIPHER"
  echo "## Mac $MAC"
  echo
  eval git annex find "${@:---include '*'}" --format="'\${hashdirmixed}\${key}/\${key} \${hashdirlower}\${key}/\${key} \${file}\n'" | while IFS=' ' read -r KEY1 KEY2 FILE; do
    echo "$REMOTE"
    echo "$FILE"
    echo "$KEY1"
    echo "$KEY2"
    bash_lookup_key "$ENCRYPTION" "$CIPHER" "$MAC" "$UUID" "$FILE"
    echo
  done
}

# Lookup special remotes keys; uses $FINDOPTS, default "*"
annex_lookup_special_remotes() {
  local RET=0
  local FINDOPTS="${FINDOPTS:---include '*'}"
  for UUID in $(annex_notdead $(annex_special "$@")); do
    annex_lookup_special_remote "$UUID" "$FINDOPTS" 2>&1 || RET=2
  done
  return $RET
}

# Lookup special remotes keys by time interval
annex_lookup_special_remotes_by_time() {
  local TIME="$1"
  shift $(($# > 1 ? 1 : $#))
  local FINDOPTS="$(git rev-list ${TIME:+--after "$TIME"} HEAD | git diff-tree --no-commit-id --name-only -r --stdin -z 2>/dev/null | xargs -r0 sh -c 'find "$@" 2>/dev/null -printf "\"%p\" "' _)"
  if test -n "$FINDOPTS"; then
    FINDOPTS="--include '*' $FINDOPTS"
    annex_lookup_special_remotes "$@"
  fi
}

########################################
# List annex content in an archive
_annex_archive() {
  ( set +e; # Need to go on on error
    annex_exists || return 1
    local OUT="${1:?No output file name specified...}"
    local DIR="${2:-$(git_dir)/bundle}"
    local NAME="$(git_repo).$(uname -n).$(date +%Y%m%d-%H%M%S).$(git_shorthash)"
    OUT="$DIR/${NAME}.${OUT%%.*}.${OUT#*.}"
    local OUTBASE="$OUT"
    local GPG_RECIPIENT="$3"
    local FINDOPTS="${4:---include='*'}" # Passed as named parameter
    local TIMEOPTS="${4}" # Passed as named parameter, same args than FINDOPTS
    local OWNER="${5:-$USER}"
    local XZOPTS="${6:--9}"
    if echo "$TIMEOPTS" | grep "@{.*}" >/dev/null; then
      FINDOPTS=""
    else
      TIMEOPTS=""
    fi
    shift 6
    if ! mkdir -p "$(dirname "$OUT")"; then
      echo "Cannot create directory '$(dirname "$OUT")'. Abort..."
      return 2
    fi
    echo "Generate $OUT"
    "$@"
    if [ $? -ne 0 ]; then
      echo "Low level command reported an error. Abort..."
      return 3
    fi
    if [ ! -s "${OUT}" ]; then
      echo "Output file '${OUT}' is missing or empty. Abort..."
      return 1
    fi
    echo "Compress into $OUT"
    xz -k -z -S .xz --verbose $XZOPTS "$OUT" &&
      git_secure_delete "$OUT"
    OUT="${OUT}.xz"
    chown "$OWNER" "$OUT"
    if [ -n "$GPG_RECIPIENT" ]; then
      echo "Encrypt bundle into '${OUT}.gpg'"
      gpg -v --output "${OUT}.gpg" --encrypt --trust-model always --recipient "$GPG_RECIPIENT" "${OUT}" &&
        git_secure_delete "${OUT}"
      OUT="${OUT}.gpg"
      chown "$OWNER" "$OUT"
    fi
    ls -l "${OUTBASE}"*
  )
}

# Annex bundle
_annex_bundle() {
  [ -n "$OUT" ] || return 1
  OUT="${OUT%%.tar}.tar"
  if annex_bare; then
    if [ -d "$(git_dir)/annex" ]; then
      echo "Skip empty bundle..."
      return 1
    fi
    tar c -h -O --exclude='*/creds/*' -- "$(git_dir)/annex" > "${OUT}"
  else
    # Skip empty bundle
    if [ $(git annex find 2>/dev/null | wc -l) -eq 0 ]; then
      echo "Skip empty bundle..."
      return 1
    fi
    git annex fsck --fast --quiet
    eval git annex find "$FINDOPTS" --print0 | 
      xargs -r0 tar c -h -O --exclude-vcs -- > "${OUT}"
  fi
  return 0
}
annex_bundle() {
  _annex_archive "annex.bundle.tar" "$1" "$2" "$3" "$4" "$5" "_annex_bundle"
}

# Annex enumeration
_annex_enum() {
  [ -n "$OUT" ] || return 1
  OUT="${OUT%%.txt}.txt"
  if annex_bare; then
    echo "Repository '$(git_dir)' cannot be enumerated. Abort..."
    return 2
  else
    eval git annex find "$FINDOPTS" --print0 | xargs -r0 -n1 sh -c '
      FILE="$1"
      #printf "\"%s\" \"%s\"\n" "$(readlink -- "$FILE")" "$FILE" | grep -F ".git/annex"
      readlink -- "$FILE" | base64 -w 0
      echo
      echo "$FILE" | base64 -w 0
      echo
    ' _ > "$OUT"
    # Skip empty bundle
    if ! test -s "$OUT"; then
      echo "Skip empty bundle..."
      rm "$OUT.txt" 2>/dev/null
      return 2
    fi
  fi
  return 0
}
annex_enum() {
  _annex_archive "annex.enum_local.txt" "$1" "$2" "$3" "$4" "$5" "_annex_enum"
}

# Store annex infos
_annex_info() {
  [ -n "$OUT" ] || return 1
  OUT="${OUT%%.txt}.txt"
  annex_getinfo > "$OUT"
  # Skip empty bundle
  if ! test -s "$OUT"; then
    echo "Skip empty bundle..."
    rm "$OUT" 2>/dev/null
    return 2
  fi
  return 0
}
annex_info(){
  _annex_archive "annex.info.txt" "$1" "$2" "$3" "$4" "$5" "_annex_info"
}

# Enum special remotes
_annex_enum_special_remotes() {
  [ -n "$OUT" ] || return 1
  OUT="${OUT%%.txt}.txt"
  annex_lookup_special_remotes_by_time "$TIMEOPTS" > "$OUT"
  # Skip empty bundle
  if ! test -s "$OUT"; then
    echo "Skip empty bundle..."
    rm "$OUT" 2>/dev/null
    return 2
  fi
  return 0
}
annex_enum_special_remotes() {
  if annex_bare; then
    echo "Repository '$(git_dir)' cannot be enumerated. Abort..."
    return 1
  else
    _annex_archive "annex.enum_special_remotes.txt" "$1" "$2" "$3" "$4" "$5" "_annex_enum_special_remotes"
  fi
}

########################################
# Export files to the specified repos by chunk of a given size
#  without downloading the whole repo locally at once
# $FROM is used to selected the origin repo
# $DBG is used to print the command on stderr (when not empty)
# $SELECT is used to select files to export; values: want-get / missing / [all]
# $FSCK is set to trigger a `fsck`
alias annex_export='SELECT=want-get _annex_export'
_annex_export() {
  annex_exists || return 1
  git_bare && echo "BARE REPOS NOT SUPPORTED YET" && return 1
  local REPOS="${1:-$(annex_exported)}"
  local MAXSIZE="${2:-4294967296}"
  local DBG="${DBG:+echo}"
  local SELECTED=""
  [ $# -le 2 ] && shift $# || shift 2
  REPOS="$(annex_remotes $REPOS)"
  [ -z "$REPOS" ] && return 0
  SELECT="${SELECT:-missing}"
  if [ "$SELECT" = "missing" ]; then
    for REPO in $REPOS; do SELECTED="${SELECTED:+ $SELECTED --or }--not --in $REPO"; done
  elif [ "$SELECT" = "want-get" ] && [ $(annex_version) -ge $(annex_version 9.0) ]; then
    for REPO in $REPOS; do SELECTED="${SELECTED:+ $SELECTED --or }-( --not --in $REPO --and --want-get-by $REPO -)"; done
  fi
  echo "REPOS=$REPOS"
  echo "MAXSIZE=$MAXSIZE"
  echo "SELECT=$SELECT"
  echo "SELECTED=$SELECTED"
  echo "FROM=$FROM"
  echo "DBG=$DBG"
  # 0) Fast fsck for links
  if [ -n "$FSCK" ]; then
    echo "Fast fsck local repo..."
    $DBG git annex fsck --fast "$@" | grep -v '^fsck.*ok$'
    for REPO in $REPOS; do
      echo "Fast fsck $REPO..."
      $DBG git annex fsck --fast --from "$REPO" "$@" | grep -v '^fsck.*ok$'
    done
  fi
  # 1) export local files
  for REPO in $REPOS; do
    echo "Export local files to $REPO..."
    $DBG git annex export HEAD --to "$REPO" | grep -v "not available"
  done
  # 2) get, export and drop remote files
  echo "Get/export remote files..."
  git annex find --include='*' $SELECTED --print0 "$@" | xargs -0 -r sh -c '
    DBG="$1";REPOS="$2";MAXSIZE="$3";FROM="$4"
    shift 4
    TOTALSIZE=0
    NUMFILES=$#
    for FILE; do
      # Init
      NUMFILES=$(($NUMFILES - 1))
      [ $TOTALSIZE -eq 0 ] && set --
      # Get current file size
      SIZE=$(git annex info --bytes "$FILE" | awk "/size:/{print \$2}")
      # List the current file
      if [ $SIZE -le $MAXSIZE ]; then
        set -- "$@" "$FILE"
        TOTALSIZE=$(($TOTALSIZE + $SIZE))
      else
        echo "File \"$FILE\" size ($SIZE) is greater than max size ($MAXSIZE). Skip it..."
      fi
      # Check if the transfer limits or last file were reached
      if [ $TOTALSIZE -ge $MAXSIZE -o $NUMFILES -eq 0 ]; then
        # Transfer the listed files so far, if any
        if [ $# -gt 0 ]; then
          $DBG git annex get ${FROM:+--from "$FROM"} "$@"
          for REPO in $REPOS; do
            $DBG git annex export HEAD --to "$REPO" | grep -v "not available"
          done
          $DBG git annex drop "$@"
        fi
        # Empty list
        set --
        TOTALSIZE=0
      fi
    done
    exit 0
  ' _ "$DBG" "$REPOS" "$MAXSIZE" "$FROM"
  # 3) fsck
  if [ -n "$FSCK" ]; then
    for REPO in $REPOS; do
      echo "Fsck $REPO..."
      $DBG git annex fsck --from "$REPO" "$@"
    done
  fi
  echo "done"
}

########################################
# Populate a (directory/rsync) special remote with local files from the input source
# NOT like "git annex export" : output files hierarchy is NOT plain, but the one of the directory/rsync special remotes
# The current repository is used to find out keys & file names, but is not used directly to copy/move the files from
# Note the same backend than the source is used for the destination file names
# WHERE selects which files & repo to look for
# MOVE=1 moves files instead of copying them
alias annex_populate='MOVE= _annex_populate'
alias annex_populatem='MOVE=1 _annex_populate'
_annex_populate() {
  annex_exists || return 1
  local DST="${1:?No dst directory specified...}"
  local SRC="${2:-$PWD}"
  local WHERE="${3:-${WHERE:---include '*'}}"
  eval git annex find "$SRC" "$WHERE" --format='\${file}\\000\${hashdirlower}\${key}/\${key}\\000' | xargs -r0 -n2 sh -c '
    DBG="$1"; MOVE="$2"; SRCDIR="$3"; DSTDIR="$4"; SRC="$SRCDIR/$5"; DST="$DSTDIR/$6"
    echo "$SRC -> $DST"
    if [ -d "$SRCDIR" -o -d "$DSTDIR" ]; then
      if [ -n "$MOVE" ]; then
        if [ -r "$SRC" -a ! -h "$SRC" ]; then
          $DBG mkdir -p "$(dirname "$DST")"
          $DBG mv -f -T "$SRC" "$DST"
        else
          $DBG rsync -K -L --protect-args --remove-source-files "$SRC" "$DST"
        fi
      else
        $DBG rsync -K -L --protect-args "$SRC" "$DST"
      fi
    fi
  ' _ "${DBG:+echo [DBG]}" "$MOVE" "$(git_root)" "$DST"
}

########################################
# Copy/Move files between remotes
# Ex: DBG= ALL= UNUSED=1 FAST= FORCE= FROM="x y" TO="x y" DROP= _annex_copy /path/to/file1 /path/to/file2
_annex_copy() {
  local DBG="${DBG:+echo}"
  local UNUSED="${UNUSED:+--unused}"
  local FAST="${FAST:+--fast}"
  local FORCE="${FORCE:+--force}"
  local ALL="${ALL:+--all}"
  local DROP="${DROP:+--want-drop}"
  local FROM=" ${FROM} " # add space prefix/suffix
  local TO=" ${TO} " # add space prefix/suffix
  annex_exists && ! annex_bare || return 1
  # Copy from remotes
  for REMOTE in $FROM; do
    if annex_isexported "$REMOTE"; then
      # Exported remotes: cannot drop files, no "move" nor "unused"
      [ -n "$UNUSED" ] && continue
      $DBG git annex copy --from "$REMOTE" ${ALL:-"${@:---want-get}"} ${FAST} ${FORCE} || return $?
      continue
    fi
    if [ -n "$UNUSED" ]; then
      $DBG git annex unused --from "$REMOTE" || return $?
    fi
    if [ -n "$DROP" ] && [ "${FROM%% $REMOTE *}" != "$FROM" ]; then
      $DBG git annex move --from "$REMOTE" ${UNUSED:-${ALL:-"${@:---want-get}"}} ${FAST} ${FORCE} || return $?
      if [ -n "$UNUSED" ]; then
        $DBG git annex dropunused --from "$REMOTE" all ${FORCE} || return $?
      fi
    else
      $DBG git annex copy --from "$REMOTE" ${UNUSED:-${ALL:-"${@:---want-get}"}} ${FAST} ${FORCE} || return $?
    fi
  done
  # Copy to remotes
  if [ "$TO" != "  " ]; then
    if [ -n "$UNUSED" ]; then
      $DBG git annex unused || return $?
    fi
    for REMOTE in $TO; do
      if [ -n "$DROP" ] && [ "${TO%% $REMOTE *}" != "$TO" ]; then
        $DBG git annex move --to "$REMOTE" ${UNUSED:-${ALL:-"${@:-${DROP}}"}} ${FAST} ${FORCE} || return $?
      else
        $DBG git annex copy --to "$REMOTE" ${UNUSED:-${ALL:-"${@:-${DROP}}"}} ${FAST} ${FORCE} || return $?
      fi
    done
    if [ -n "$DROP" ]; then
      $DBG git annex drop ${UNUSED:-${ALL:-"${@:-${DROP:+--auto}}"}} ${FAST} ${FORCE} || return $?
    fi
    if [ -n "$UNUSED" ]; then
      $DBG git annex dropunused all ${FORCE} || return $?
    fi
  fi
}
annex_copy() { DROP="" _annex_copy "$@"; }
annex_move() { DROP=1 _annex_copy "$@"; }
annex_unload() { UNUSED=1 DROP=1 _annex_copy "$@"; }

########################################
# Drop local files which are in the specified remote repos
alias annex_drop='git annex drop -N $(annex_enabled | wc -w)'
annex_drop_fast() {
  annex_exists || return 1
  local REPOS="${1:-$(annex_enabled)}"
  local COPIES="$(echo "$REPOS" | wc -w)"
  local LOCATION="$(echo "$REPOS" | sed -e 's/ / --and --in /g')"
  [ $# -gt 0 ] && shift
  git annex drop --in "$LOCATION" -N "$COPIES" "$@"
}

########################################
# Annex upkeep
annex_upkeep() {
  local DBG=""
  local IFS="$(printf ' \t\n')"
  # Add options
  local ADD=""
  local DEL=""
  local FORCE=""
  local ALL=""
  # Sync options
  local MSG="annex_upkeep() at $(date)"
  local SYNC=""
  local NO_COMMIT="--no-commit"
  local NO_PULL="--no-pull"
  local NO_PUSH="--no-push"
  local CONTENT=""
  local DROP=""
  local UNUSED=""
  # Copy options
  local GET=""
  local SEND=""
  local MOVE=""
  local FAST="--all"
  local REMOTES=""
  # Get arguments
  OPTIND=1
  while getopts "adoscputnlm:gevxfz" OPTFLAG; do
    case "$OPTFLAG" in
      # Add
      a) ADD=1;;
      d) DEL=1;;
      o) FORCE=1;;
      # Sync
      s) SYNC=1; NO_COMMIT=""; NO_PULL=""; NO_PUSH="";;
      c) SYNC=1; NO_COMMIT="";;
      p) SYNC=1; NO_PULL="";;
      u) SYNC=1; NO_PUSH="";;
      t) SYNC=1; CONTENT="--content";;
      n) SYNC=1;;
      l) UNUSED="--unused";;
      m) MSG="${OPTARG}";;
      # UL/DL
      g) GET=1;;
      e) SEND=1;;
      v) MOVE=1;;
      x) DROP=1;;
      f) FAST="--fast";;
      y) ALL="--all";;
      # Misc
      z) set -vx; DBG="true";;
      *) echo >&2 "Usage: annex_upkeep [-a] [-d] [-o] [-s] [-c] [-p] [-u] [-t] [-n] [-l] [-m 'msg'] [-g] [-e] [-x] [-f] [-y] [-z] [remote1 remote2 ...] "
         echo >&2 "-a (a)dd files"
         echo >&2 "-d commit (d)eleted files"
         echo >&2 "-o f(o)rce add/delete files"
         echo >&2 "-s (s)ync, similar to -cpu"
         echo >&2 "-c (c)ommit"
         echo >&2 "-p (p)ull"
         echo >&2 "-u p(u)sh"
         echo >&2 "-t sync conten(t)"
         echo >&2 "-n sy(n)c, push, pull"
         echo >&2 "-l list unused"
         echo >&2 "-m (m)essage"
         echo >&2 "-g (g)et"
         echo >&2 "-e s(e)nd to remotes"
         echo >&2 "-v mo(v)e files"
         echo >&2 "-x drop files"
         echo >&2 "-f (f)ast get/send"
         echo >&2 "-y all files"
         echo >&2 "-z simulate operations"
         return 1;;
    esac
  done
  shift "$((OPTIND-1))"
  unset OPTFLAG OPTARG
  OPTIND=1
  REMOTES="${@:-$(annex_enabled)}"
  # Base check
  annex_exists || return 1
  # Force PULL if a remote is using gcrypt
  if [ -n "$NO_PULL" ] && git_gcrypt_remotes $REMOTES; then
    echo "Force pull because of gcrypt remote(s)"
    unset NO_PULL
  fi
  # Add
  if [ -n "$ADD" ]; then
    $DBG git annex add . ${FORCE:+--force} || return $?
  fi
  # Revert deleted files
  if [ -z "$DEL" ] && ! annex_direct; then
    gstx D | xargs -r0 $DBG git reset HEAD -- || return $?
    #annex_st D | xargs -r $DBG git checkout || return $?
  fi
  # Sync
  if [ -n "$SYNC" ]; then
    $DBG git annex sync ${NO_COMMIT} ${NO_PULL} ${NO_PUSH} ${CONTENT} ${MSG:+--message="$MSG"} $REMOTES || return $?
  fi
  # Unused
  if [ -n "$UNUSED" ]; then
    $DBG git annex unused || return $?
  fi
  # Get
  if [ -n "$GET" ]; then
    $DBG git annex get ${FAST} ${ALL:-.} || return $?
  fi
  # Send
  if [ -n "$SEND" ]; then
    for REMOTE in ${REMOTES}; do
      $DBG git annex copy --to "$REMOTE" ${UNUSED:-${FAST} ${ALL:-.}} || return $?
    done
  fi
  # Move
  if [ -n "$MOVE" ]; then
    # Copy over all but the last remote
    for REMOTE in ${REMOTES% *}; do
      $DBG git annex copy --to "$REMOTE" ${UNUSED:-${FAST} ${ALL:-.}} || return $?
    done
    # Move to the last remote
    REMOTE="${REMOTES##* }"
    $DBG git annex move --to "$REMOTE" ${UNUSED:-${FAST} ${ALL:-.}} || return $?
  fi
  # Drop
  if [ -n "$DROP" ]; then
    $DBG git annex drop ${UNUSED:-${FAST} ${ALL:-.}} || return $?
  fi
  return 0
}

########################################
# Find aliases
alias annex_existing='git annex find --in'
alias annex_existing0='git annex find --print0 --in'
alias annex_missing='git annex find --not --in'
alias annex_missing0='git annex find --print0 --not --in'
annex_existingc() { annex_existing "$@" | wc -l; }
annex_missingc()  { annex_missing "$@" | wc -l; }
annex_lost()  { git annex list "$@" | grep -E "^_+ "; }
annex_lostc() { git annex list "$@" | grep -E "^_+ " | wc -l; }

# Want aliases
annex_wantget()   { annex_missing "$1" --want-get-by "$1"; }
annex_wantget0()  { annex_missing "$1" --want-get-by "$1" --print0; }
annex_wantdrop()  { annex_existing "$1" --want-drop-by "$1"; }
annex_wantdrop0() { annex_existing "$1" --want-drop-by "$1" --print0; }
annex_wantgetc()  { annex_wantget "$@" | wc -l; }
annex_wantdropc() { annex_wantdrop "$@" | wc -l; }

# Grouped find aliases
annex_existingn()  { for UUID in $(annex_notdead "$@"); do echo "*** Existing in $(annex_remotes $UUID) ($UUID) ***"; annex_existing "$UUID"; done; }
annex_missingn()   { for UUID in $(annex_notdead "$@"); do echo "*** Missing in $(annex_remotes $UUID) ($UUID) ***"; annex_missing "$UUID"; done; }
annex_existingnc() { for UUID in $(annex_notdead "$@"); do echo -n "Num existing in $(annex_remotes $UUID) ($UUID) : "; annex_existingc "$UUID"; done; }
annex_missingnc()  { for UUID in $(annex_notdead "$@"); do echo -n "Num missing in $(annex_remotes $UUID) ($UUID) : "; annex_missingc "$UUID"; done; }

# Grouped want aliases
annex_wantgetn()  { for UUID in $(annex_notdead "$@"); do echo "*** Want-get in $(annex_remotes $UUID) ($UUID) ***"; annex_wantget "$UUID"; done; }
annex_wantdropn() { for UUID in $(annex_notdead "$@"); do echo "*** Want-drop in $(annex_remotes $UUID) ($UUID) ***"; annex_wantdrop "$UUID"; done; }
annex_wantgetnc() { for UUID in $(annex_notdead "$@"); do echo -n "Num want-get in $(annex_remotes $UUID) ($UUID) : "; annex_wantgetc "$UUID"; done; }
annex_wantdropnc(){ for UUID in $(annex_notdead "$@"); do echo -n "Num want-drop in $(annex_remotes $UUID) ($UUID) : "; annex_wantdropc "$UUID"; done; }

# Is file in annex ?
annex_isin() {
  annex_exists || return 1
  local REPO="${1:-.}"
  shift
  [ -n "$(git annex find --in "$REPO" "$@")" ]
}

# Find annex repositories
annex_find_repo() {
	git_find0 "$@" |
		while read -d $'\0' DIR; do
			annex_exists "$DIR" && printf "'%s'\n" "$DIR"
		done 
}

# Set preferred content using local files
annex_preferred() {
  annex_exists || return 1
  local REPO="${1:-.}"
  local REQUIRED="${2:-.required}"
  local WANTED="${3:-.wanted}"
  if [ -r "$REQUIRED" ]; then
    cat "$REQUIRED" | xargs -d\\n -r -n1 -- sh -c 'eval git annex required $*' _
  fi
  if [ -r "$WANTED" ]; then
    cat "$WANTED" | xargs -d\\n -r -n1 -- sh -c 'eval git annex wanted $*' _
  fi
}

# Find plain files in annex
# https://stackoverflow.com/questions/61680637/list-all-files-in-git-repo-not-added-by-git-annex-add
annex_find_plain() {
  local TMP1="${1:-$(mktemp)}"
  local TMP2="${2:-$(mktemp)}"
  git ls-files > "$TMP1"
  git annex find > "$TMP2"
  awk 'FNR==NR {a[$0]++; next} !a[$0]' "$TMP2" "$TMP1"
}

########################################
# Fsck all
annex_fsck() {
  local PARAM1="$1"
  [ $# -ge 1 ] && shift
  for UUID in $(annex_notdead "$PARAM1"); do
    git annex fsck --from="${UUID}" "$@"
  done
}

########################################
# Rename normal remote
annex_rename_remote() {
  local FROM="${1:?No remote to rename from...}"
  local TO="${2:?No remote to rename to...}"
  annex_exists || return 1
  ! annex_modified || return 2
  local BRANCH="$(git_branch)"
  git config --rename-section filter.annex tmp_annex
  git checkout git-annex
  sed -ie "s/ $FROM / $TO /" uuid.log
  git diff
  read -p "Press enter to go on" _
  git add uuid.log &&
    git commit -m "Rename remote $FROM into $TO"
  git diff HEAD~1
  read -p "Press enter to go on" _
  git checkout "$BRANCH"
  git config --rename-section tmp_annex filter.annex
}

# Rename special remotes
annex_rename_special() {
  git annex renameremote "$@"
  #~ git config remote.$1.fetch "dummy"
  #~ git remote rename "$1" "$2"
  #~ git config --unset remote.$2.fetch
  #~ git annex initremote "$1" name="$2"
}

# Revert changes in all modes (indirect/direct)
annex_revert() {
  git annex proxy -- git revert "${1:-HEAD}"
}

# Annex info
alias annex_du='git annex info --fast'

########################################
# Find files from key
# A file can have had multiple names
annex_fromkey0_all() {
  for KEY; do
    KEY="$(basename "$KEY")"
    #git show -999999 -p --no-color --word-diff=porcelain -S "$KEY" | 
    #git log -n 1 -p --no-color --word-diff=porcelain -S "$KEY" |
    git log -p --all --no-color --no-textconv --word-diff=porcelain -S "$KEY" |
      awk '/^(---|\+\+\+) (a|b)/{line=$0} /'$KEY'/{printf "%s\0",substr(line,5); exit 0}' |
      # Remove leading/trailing double quotes, leading "a/", trailing spaces. Escape '%'
      sed -z -e 's/\s*$//' -e 's/^"//' -e 's/"$//' -e 's/^..//' -e 's/%/\%/g' |
      # Remove duplicated files
      uniq -z |
      # printf does evaluate octal charaters from UTF8
      xargs -r0 -I {} -- printf "{}\0"
      # Sanity extension check between key and file
      #xargs -r0 -n1 sh -c '
        #[ "${1##*.}" != "${2##*.}" ] && printf "Warning: key extension ${2##*.} mismatch %s\n" "${1##*/}" >&2
        #printf "$2\0"
      #' _ "$KEY"
  done
}
annex_fromkey_all() {
  annex_fromkey0_all "$@" | xargs -r0 -n1
}

annex_fromkey0() {
  for KEY; do
    KEY="$(basename "$KEY")"
    git log -p --all --no-color --no-textconv --word-diff=porcelain -S "$KEY" |
      awk '/^(---|\+\+\+) (a|b)/{line=$0} /'$KEY'/{printf "%s\0",substr(line,5); exit 0}' |
      # Remove leading/trailing double quotes, leading "a/", trailing spaces. Escape '%'
      sed -z -e 's/\s*$//' -e 's/^"//' -e 's/"$//' -e 's/^..//' -e 's/%/\%/g' |
      # Limit output to the first one
      head -z -n 1 |
      # printf does evaluate octal charaters from UTF8
      xargs -r0 -I {} -- printf "{}\0"
  done
}
annex_fromkey() {
  annex_fromkey0 "$@" | xargs -r0 -n1
}

# Check if key exists in the annex (use the default backend)
annex_key_exists() {
  for KEY; do
    annex_fromkey0_all "$KEY" | xargs -r0 git annex find | grep -m 1 -e "." >/dev/null && echo "$KEY"
  done
}

# Check if input file exists in the annex (use the default backend)
annex_file_exists() {
  for FILE; do
    local KEY="$(git annex calckey "$FILE")"
    # Search without the key file extension
    annex_key_exists "${KEY%%.*}" >/dev/null && echo "$KEY $FILE"
  done
}

# Get key from file name
annex_getkey() {
  git annex find --include='*' "${@}" --format='${key}\000'
}
annex_gethashdir() {
  git annex find --include='*' "${@}" --format='${hashdirlower}\000'
}
annex_gethashdirmixed() {
  git annex find --include='*' "${@}" --format='${hashdirmixed}\000'
}
annex_gethashpath() {
  git annex find --include='*' "${@}" --format='${hashdirlower}${key}/${key}\000'
}
annex_gethashpathmixed() {
  git annex find --include='*' "${@}" --format='${hashdirmixed}${key}/${key}\000'
}

########################################
# Find unused files
annex_unused() {
  git annex unused "$@" ${FROM:+--from $FROM} ${REFS:+--used-refspec $REFS} ${FAST:+--fast}
}

# Count unused files
annex_unusedc() {
  annex_unused "$@" | wc -l
}

# Group list unused files
annex_unusedn() { for UUID in $(annex_notdead "$@"); do echo "*** Unused in $(annex_remotes $UUID) ($UUID) ***"; FROM="$UUID" annex_unused; done; }
annex_unusednc() { for UUID in $(annex_notdead "$@"); do echo -n "Num unused in $(annex_remotes $UUID) ($UUID) : "; FROM="$UUID" annex_unused | wc -l; done; }

# Drop all unused files
annex_dropunused() {
  annex_exists && ! annex_bare || return 1
  local LAST="$(annex_unused | awk '/^\s+[0-9]+\s/ {a=$1} END{print a}')"
  git annex dropunused ${FROM:+--from $FROM} ${FORCE:+--force} "$@" 1-${LAST:?Nothing to drop...}
}
annex_dropunused_all() {
  annex_exists && ! annex_bare || return 1
  REFS=+HEAD annex_dropunused "$@"
}

# Drop partially transfered files
annex_dropunused_partial() {
  annex_exists && ! annex_bare || return 1
  annex_unused --fast | 
    awk '/^\s+[0-9]+\s+/ {print $1}' | 
    xargs -r git annex dropunused ${FROM:+--from $FROM} ${FORCE:+--force}
}

# List unused files, matching pattern
annex_listunused_by_pattern() {
  annex_exists && ! annex_bare || return 1
  local IFS="$(printf ' \t\n')"
  local PATTERNS=""
  local ARG
  for ARG; do PATTERNS="${PATTERNS:+$PATTERNS }-e '$ARG'"; done
  annex_unused | grep -E '^\s+[0-9]+\s' | 
    while IFS=' ' read -r NUM KEY; do
      annex_fromkey0_all "$KEY" |
        eval grep --color=never -z "${PATTERNS:-''}" &&
          echo -e "$NUM $KEY" && break
    done
}

# Drop unused files matching pattern
annex_dropunused_by_pattern() {
  annex_exists && ! annex_bare || return 1
  annex_listunused_by_pattern "$@" |
    awk -F' ' '{print $1}' |
    xargs -r git annex dropunused ${FROM:+--from $FROM} ${FORCE:+--force}
}

# Copy unused files matching pattern
annex_copyunused_by_pattern() {
  annex_exists && ! annex_bare || return 1
  annex_listunused_by_pattern "$@" |
    awk -F' ' '{print $1}' |
    xargs -rn1 -I{} -- git annex copy --key={} ${FROM:+--from $FROM} ${TO:+--to $TO} ${FORCE:+--force}
}

# Move unused files matching pattern
annex_moveunused_by_pattern() {
  annex_exists && ! annex_bare || return 1
  annex_listunused_by_pattern "$@" |
    awk -F' ' '{print $1}' |
    xargs -rn1 -I{} -- git annex move --key={} ${FROM:+--from $FROM} ${TO:+--to $TO} ${FORCE:+--force}
}

########################################
# Forget a special remote
annex_forget_remote() {
  # Confirmation
  local REPLY; read -r -p "Forget remotes (and cleanup git-annex history)? (y/n) " REPLY < /dev/tty
  [ "$REPLY" != "y" -a "$REPLY" != "Y" ] && return 3
  local OK=1
  for REMOTE; do
    git remote remove "$REMOTE" &&
    git annex dead "$REMOTE" ||
    OK=""
  done
  [ -n "$OK" ] && git annex forget --drop-dead --force
}

# Delete all versions of a file
# https://git-annex.branchable.com/tips/deleting_unwanted_files/
annex_purge() {
  local REPLY
  annex_exists || return 1
  [ $# -gt 0 ] || return 2
  ! git_modified || { echo "Error: the repo is not clean."; return 3; }
  printf "You are about to delete %d file(s) or folder(s) definitively !\n\n%s\n\nProceed ? (y/n) " $# "$*"
  read REPLY </dev/tty
  [ "$REPLY" = "y" -o "$REPLY" = "Y" ] || return 1
  for R in $(annex_enabled $(annex_notexported "$@")); do
    git annex drop --force --from "$R" "$@" || return $?
  done
  git annex drop --force "$@" || return $?
  git rm -r "$@"
  git annex sync
  for R in $(annex_enabled $(annex_exported "$@")); do
    git annex export --fast "$(git_branch)" --to "$R"
  done
}

# Cleanup annex
annex_clean() {
  : ${TO:?No repo(s) to move unused files to...}
  local DBG=${DBG:+echo}
  local FORCE=${FORCE:+1}
  local ALL=${ALL:+1}
  local AUTO=${AUTO:+1}
  local DIR
  annex_exists || return 1
  ${DBG} rm -rf .git/annex/tmp/ .git/annex/othertmp/ .git/annex/bad/ .git/annex/transfer/ .git/annex/ssh/ .git/annex/index .git/annex/journal/ .git/annex/export/ .git/annex/export.ex/
  UNUSED=1 FORCE="$FORCE" TO="$TO" ALL="$ALL" annex_move
  git annex drop ${AUTO:+--auto} ${ALL:+--all} ${FORCE:+--force}
  git_gc_purge
}

########################################
# Set a remote key presence flag
# WHERE selects which files & repo to look for
# DBG enable debug mode
annex_setpresentkey() {
  local REMOTE="${1:?No remote specified...}"
  local WHERE="${2:-${WHERE:---include \*}}"
  local PRESENT="${3:-1}"
  local UUID="$(git config --get remote.${REMOTE}.annex-uuid)"
  [ -z "$UUID" ] && { echo "Remote $REMOTE unknown..." && return 1; }
  eval git annex find "$WHERE" --format="\${key} $UUID $PRESENT\n" |
    ${DBG:+echo "[DBG]"} git annex setpresentkey --batch
}

# Declare present and missing files; Files must be accessible from a mountpoint
# WHERE selects which files & repo to look for
# DBG enable debug mode
annex_setpresentfiles() {
  local REMOTE="${1:?No remote specified...}"
  local DIR="${2:?No remote folder to compare to...}"
  local WHERE="${3:-${WHERE:---include \*}}"
  local PRESENT="$4"
  local UUID="$(git config --get remote.${REMOTE}.annex-uuid)"
  [ -z "$UUID" ] && { echo "Remote $REMOTE unknown..." && return 1; }
  eval git annex find "$WHERE" --format='\${key}\\000\${file}\\000' | xargs -r0 -n2 sh -c '
    DBG="$1"; UUID="$2"; DIR="$3"; FLAG="$4"; KEY="$5"; FILE="$6"
    [ -f "$DIR/$FILE" ] && PRESENT=1 || PRESENT=0
    if [ -n "$FLAG" ] && [ "$FLAG" != "$PRESENT" ]; then
      echo "P$PRESENT F$FLAG: skip $FILE"
    else
      ${DBG:+true} echo "P$PRESENT${FLAG:+ F$FLAG}: flag $FILE"
      ${DBG:+echo "[DBG]"} git annex setpresentkey "$KEY" "$UUID" $PRESENT
    fi
  ' _ "$DBG" "$UUID" "$DIR" "$PRESENT"
}

########################################
# Find duplicates
annex_duplicates0() {
  local DIR="${1:-.}"
  local FILTER="${2:---all-repeated=separate}"
  git annex find "$DIR" --include '*' --format='${file} ${escaped_key}\000' |
      sort -zk2 | uniq -z $FILTER -f1 |
      sed -z 's/ [^ ]*$//'
}
annex_duplicates() {
  annex_duplicates0 "$@" |
    xargs -r0 -n1
}

# Remove one duplicate
annex_rm_duplicates() {
  annex_duplicates0 "$1" --repeated |
    xargs -r0 echo git rm
}

########################################
annex_commit_enable() {
  git config --unset "annex.autocommit" false
}
annex_commit_disable() {
  git config --add "annex.autocommit" false
}

########################################
# Annex aliases
alias gan='git annex'
alias gana='git annex add'
alias gant='git annex status'
alias gantn='annex_st \\?'
alias gantm='annex_st M'
alias ganl='git annex list'
alias ganls='git annex list'
alias ganlc='git annex find | wc -l'
alias ganf='git annex find'
alias ganfc='git annex find | wc -l'
alias gans='git annex sync --no-content'
alias gansnc='git annex sync --no-content --no-commit'
alias gansnup='git annex sync --no-content --no-pull'
alias gansnpu='git annex sync --no-content --no-push'
alias gansnpp='git annex sync --no-content --no-push --no-pull'
alias gansc='git annex sync --content'
alias ganscf='git annex sync --content --fast'
alias gang='git annex get'
alias ganm='git annex move'
alias ganmt='git annex move --to'
alias ganmf='git annex move --from'
alias ganc='git annex copy'
alias ganct='git annex copy --to'
alias gancf='git annex copy --from'
alias gane='git annex export'
alias gand='git annex drop'
alias gani='git annex info'
alias ganu='git annex unlock'
alias ganms='annex_missing'
alias ganwg='annex_wantget'
alias ganwd='annex_wantdrop'
# Assistant
alias ganas='git annex assistant'
alias ganw='git annex webapp'

########################################
########################################
# Last commands in file
# Execute function from command line
[ "${1#annex}" != "$1" ] && "$@" || true
