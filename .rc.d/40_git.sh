#!/bin/sh

# Editors
export GIT_EDITOR="${EDITOR:-vi}"
export GIT_PAGER="${PAGER:-less}"

########################################
# Dependencies

# Ask question
command -v "ask_question" >/dev/null 2>&1 ||
ask_question() {
  local ANSWER
  echo -n "$1 " >&2
  read ANSWER
  echo "$ANSWER" >&2
  shift
  local ARG
  for ARG; do
    [ "$ARG" = "$ANSWER" ] && return 0
  done
  return 1
}

########################################
# git wrapper
#git() {
#  # Forbid git annex in direct mode with VCSH
#  if [ "$1" = "annex" -a -n "$(command git config --get vcsh.vcsh)" ]; then
#    if [ "$(command git config --get annex.direct)" = "true" -o "$2" = "direct" ]; then
#      echo "git annex in direct mode is not compatible with VCSH repositories..." >&2
#      return 1
#    fi
#  fi
#  # VCSH repository not loaded yet
#  if [ -z "$GIT_WRAPPER" ] && [ -z "$VCSH_REPO_NAME" ] && command git config --get vcsh.vcsh >/dev/null 2>&1; then
#    local GIT_WRAPPER=1
#    vcsh "$(git_repo)" "$@"
#  else
#    command git "$@"
#  fi
#}

########################################
# Env setup
git_setup() {
cat <<EOF
  # Push (either simple, upstream or current)
  git config --global --unset-all push.default
  git config --global --add push.default current
  # Pull
  git config --global pull.rebase preserve
  # Diff
  git config --global --unset-all diff.tool
  git config --global --unset-all difftool
  git config --global diff.tool mydiff
  git config --global difftool.mydiff.cmd \
    'meld --diff "\$LOCAL" "\$REMOTE" 2>/dev/null || true'
  git config --global difftool.mydiff.trustExitCode false
  # Merge
  git config --global --unset-all merge.tool
  git config --global --unset-all mergetool
  git config --global merge.tool mymerge
  git config --global merge.conflictstyle diff3
  git config --global mergetool.mymerge.cmd \
    'meld --diff "\$LOCAL" "\$MERGED" "\$REMOTE" --diff "\$BASE" "\$LOCAL" --diff "\$BASE" "\$REMOTE" 2>/dev/null'
  git config --global mergetool.mymerge.trustExitCode true
  # Misc
  git config --global rerere.enabled true
  git config --global core.excludesfile '~/.gitignore'
  # Disable push in gcrypt remotes; enable the one you want manually
  for REMOTE in $(git_remotes); do
    git_gcrypt_remotes "$REMOTE" && echo "Disable push in remote $REMOTE" && git_push_disable "$REMOTE"
  done
  # Git memory usage options
  # https://stackoverflow.com/questions/4826639/repack-of-git-repository-fails
  # https://stackoverflow.com/questions/10292903/git-on-windows-out-of-memory-malloc-failed
  # http://git-scm.com/book/en/Git-Internals-Git-Objects
  if [ "$1" = "low" ];
    # git core
    git config core.packedGitWindowSize 32m
    git config core.packedGitLimit 32m
    git config core.deltaCacheSize 32m
    # git repack
    git config pack.windowMemory 32m
    git config pack.packSizeLimit 32m
    git config pack.deltacachesize 32m
    #git config pack.window 2 # 0 to disable delta compression globally (larger repo size on disk)
    git config pack.threads 1
  fi
  # Autosquash all interactive rebases
  git config --global rebase.autosquash true
EOF
}

# Configure the repos
git_config_set() { git config --replace-all "$@"; }
git_config_rm() { git config --unset-all "$1"; }
git_config_set_remotes() { local REMOTE; for REMOTE in $(git_remotes "$1"); do git config --replace-all "remote.$REMOTE.$2" "$3"; done; }
git_config_rm_remotes() { local REMOTE; for REMOTE in $(git_remotes "$1"); do git config --unset-all "remote.$REMOTE.$2"; done; }

########################################
# Set shadow-like clone (only specific branch)
git_set_shallow() {
  local REMOTE="${1:?No remote specified...}"
  local BRANCH="${2:-*}"
  git config --unset-all "remote.$REMOTE.fetch"
  for BRANCH in $BRANCHES; do
    git config "remote.$REMOTE.fetch" "+refs/heads/$BRANCH:refs/remotes/$REMOTE/$BRANCH"
  done
}

# Set sparse checkout (only specific refs/folders)
git_set_sparse_checkout() {
  git config core.sparseCheckout true
  for D; do
    echo "$D" >> .git/info/sparse-checkout
  done
}

# Partial clones
git_clone_empty() { git clone --no-checkout "$@"; }
git_clone_shallow() { git clone --no-checkout --depth "$@"; } # implies --single-branch
git_clone_single() { git clone --no-checkout --single-branch -b "$@"; }

# Incremental clone
git_clone_inc() {(
  set -e
  local REPO="$1"
  local DIR="$2"
  git clone --recurse-submodules --no-checkout --depth=1 "$REPO" "$DIR"
  cd "$DIR"
  git config remote.origin.fetch "+refs/heads/*:refs/remotes/origin/*"
  git_fetch_inc
  git pull
)}

# Incremental fetch
git_fetch_inc() {
  local N=1
  while [ $N -le ${1:-10000000} ]; do
    git fetch --depth=$N
    N=$(($N * 10))
  done
}

########################################
# Get git version
git_version() {
  GIT_VERSION="${GIT_VERSION:-$(git --version 2>/dev/null | cut -d' ' -f 3)}"
  echo "${1:-$GIT_VERSION}" | awk -F'.' '{r=sprintf("%.d%.2d%.2d%.2d",$1,$2,$3,$4); sub("^0+","0",r); print r}'
}

# Check repo exists
git_exists() {
  git ${1:+--git-dir="$1"} rev-parse >/dev/null 2>&1 ||
  git ${1:+--git-dir="${1}/.git"} rev-parse >/dev/null 2>&1 ||
  (command cd "$1" 2>/dev/null && git rev-parse >/dev/null 2>&1)
}

# Get git directory (alias git-dir)
git_dir() {
  local DIR="$1"
  readlink -f "$(git ${DIR:+--git-dir="$DIR/.git"} rev-parse --git-dir 2>/dev/null)" ||
  readlink -f "$(git ${DIR:+--git-dir="$DIR"} rev-parse --git-dir 2>/dev/null)"
}
git_user_dir() {
  echo "$(git_dir "$@")/user"
}

# Check bare repo attribute
git_bare() {
  [ "$(git ${1:+--git-dir="$1"} config --get core.bare)" = "true" ]
}

# Get git worktree directory
git_worktree() {
  git ${1:+--git-dir="$1"} rev-parse --show-toplevel
}

# Get git exec-path
git_exp() {
  git --exec-path
}

# Get git-dir basename
git_repo() {
  local DIR="$(git_dir)"
  [ "${DIR##*/}" = ".git" ] && 
    basename "${DIR%/*}" .git || 
    basename "$DIR" .git
}

# Get git root (git-dir for bare repos or worktree for non-bare repos)
git_root() {
  git_bare "$@" && git_dir "$@" || git_worktree "$@"
}

# Check if we are at the top level directory
git_top() {
  [ "$(git_root 2>/dev/null)" = "$PWD" ]
}

# Unlock repo
git_unlock() {
  rm -v "$(git_dir "$@")/index.lock"
}

# Refresh index
git_update_index() {
  git_stx "" "$1" | xargs -r0 -n1 git update-index -q --refresh
}
git_update_index_all() {
  git ls-files -z ${1:+"$1"} | xargs -r0 -n1 git update-index -q --refresh
}

# Find repos and execute commands in them
git_foreach() {
  git_find0_repo | xargs -r0 -- sh -c '
    CMD="$1"; shift
    for DIR; do
      (export GIT_DIR="$DIR"; echo "$DIR"; eval "${CMD}")
    done
  ' _ "$1"
}

########################################

# Get current branch name
# Hide errors when ref is unknown
git_branch() {
  #git ${2:+--git-dir="$2"} rev-parse --abbrev-ref "${1:-HEAD}" 2>/dev/null
  #git branch -a | grep -E '^\*' | cut -c 3-
  #git for-each-ref --format='%(objectname) %(refname:short)' refs/heads | awk "/^$(git rev-parse HEAD)/ {print \$2}"
  # The following works for detached heads too
  #{ git ${2:+--git-dir="$2"} symbolic-ref "${1:-HEAD}" 2>/dev/null || echo "detached_head"; } | sed 's;refs/heads/;;'
  git ${2:+--git-dir="$2"} symbolic-ref --short "${1:-HEAD}" 2>/dev/null || echo "detached_head"
}

# Show the last commit of each branch
git_branches_head() {
  for BRANCH in $(git branch -r | grep -v HEAD); do
    echo -e $(git show --format="%ai %ar by %an" $BRANCH | head -n 1) \\t$BRANCH
  done | sort -r
}

# Get default-branch
git_branch_default() {
  git ${2:+--git-dir="$2"} remote show "${1:?No remote specified...}" | sed -n '/HEAD/s/.*: //p'
}

# Get current branch tracking
alias git_tracking_remote='git_tracking | sed -s "s;/.*;;"'
alias git_tracking_branch='git_tracking | sed -s "s;.*/;;"'
git_get_tracking() {
  git ${2:+--git-dir="$2"} rev-parse --abbrev-ref --symbolic-full-name "$1@{upstream}" 2>/dev/null | grep -v '@{upstream}'
  #git for-each-ref --format='%(upstream:short)' $(git symbolic-ref -q HEAD) 2>/dev/null
}
git_tracking() {
  local TRACKING="$(git_get_tracking "$@")"
  [ -z "$TRACKING" ] && echo "$(git_remotes | cut -d ' ' -f 1)/$(git_branch)" ||
  echo "${TRACKING:-$(git_remotes | cut -d ' ' -f 1)/$(git_branch)}"
}

# Set default tracking
if [ $(git_version) -ge $(git_version 2.0) ]; then
git_set_tracking() {
  local REMOTE="${1:-$(git_remotes | cut -d' ' -f 1)}"
  local BRANCH="${2:-$(git_branch)}"
  if git for-each-ref "refs/remotes/$REMOTE" | grep -- "refs/remotes/$REMOTE/$BRANCH\$" >/dev/null; then
    git ${3:+--git-dir="$3"} branch --set-upstream-to "$REMOTE/$BRANCH" "$BRANCH"
  else
    echo >&2 "Remote branch $REMOTE/$BRANCH does not exist. Push and set tracking branch at once with:"
    echo >&2 "git push -u $REMOTE $BRANCH"
    return 1
  fi
}
else
git_set_tracking() {
  local REMOTE="${1:-$(git_remotes | cut -d' ' -f 1)}"
  local BRANCH="${2:-$(git_branch)}"
  if git for-each-ref "refs/remotes/$REMOTE" | grep -- "refs/remotes/$REMOTE/$BRANCH\$" >/dev/null; then
    git ${3:+--git-dir="$3"} branch --set-upstream "$BRANCH" "$REMOTE/$BRANCH"
  else
    echo >&2 "Remote branch $REMOTE/$BRANCH does not exist. Push and set tracking branch at once with:"
    echo >&2 "git push -u $REMOTE $BRANCH"
    return 1
  fi
}
fi

# Get all local branches
git_branches() {
  #git ${1:+--git-dir="$1"} for-each-ref --shell refs/heads/ --format='%(refname:short)' | sed -e 's;heads/;;' | xargs echo 
  git ${1:+--git-dir="$1"} for-each-ref --format='%(refname:short)' refs/heads/ | xargs echo
}

# List all branches info
git_branches_info() {
  for branch in $(git branch -r $@ | grep -v HEAD); do
    echo -e $(git show --format="%ci %cr %an" $branch | head -n 1) \\t$branch
  done | sort -r
}

# Check a branch exists
git_branch_exists() {
  git ${2:+--git-dir="$2"} show-ref "$1" >/dev/null
}
git_branch_exists_local() {
  git_branch_exists "refs/heads/$1" "$2"
}
git_branch_exists_remote() {
  git_branch_exists "refs/remotes/$1" "$2"
}

# Set an existing branch to a given SHA1 without checking it out
# Push it with: git push <remote> <branch>:<branch>
git_branch_jump() {
  git update-ref "refs/heads/${1:?No branch specified...}" "${2:?No destination specified...}"
}

# Set default ref branch.
# Useful to set default checked-out branch in bare repos
# Ex: git symbolic-ref HEAD refs/heads/master -> set bare repo HEAD to master
git_branch_set_ref() {
  git symbolic-ref "${2:?No ref specified...}" "refs/heads/${1:?No branch specified...}"
}

# List remote branches without network access
git_branch_remote() {
  git for-each-ref ${2:+--git-dir="$2"} --format='%(refname:short)' refs/remotes${1:+/$1}
}

# List remote branches with network access
git_branch_ls_remote() {
  git ls-remote --heads | awk '{print substr($2,12)}'
}

# Delete local untracked branch (safely)
git_branch_delete_local() {
  for REFS; do
    local BRANCH="${REFS#*/}"
    echo "Delete local branch '$BRANCH'"
    git tag "$(git_name deleted.local)" "refs/head/$BRANCH" &&
      git branch -d "$BRANCH"
  done
}

# Delete remote untracked branch (safely)
git_branch_delete_remote() {
  for REFS; do
    local REMOTE="${REFS%%/*}"
    local BRANCH="${REFS#*/}"
    echo "Delete remote branch '$REFS'"
    git tag "$(git_name deleted.remote.${REMOTE#*/})" "remotes/$REFS" && {
      git push "$REMOTE" ":$BRANCH" || git branch -rd "$REFS"
    }
  done
}

# Delete local and remote branches
git_branch_delete_both() {
  for REFS; do
    git_branch_delete_local "$REFS"
    git_branch_delete_remote "$REFS"
  done
}

# Rename remote branch
# https://stackoverflow.com/questions/30590083/how-do-i-rename-both-a-git-local-and-remote-branch-name#30590238
git_branch_rename_remote() {
  local OLD="${1:?No old branch name specified...}"
  local NEW="${2:?No new branch name specified...}"
  local REMOTE="${3:-origin}"
  git push "$REMOTE" "$REMOTE/$OLD":"refs/heads/$NEW" :"$OLD"
}

# Get merged branches
git_branch_ls_merged() {
  git ${3:+--git-dir="$3"} branch --${2:+no-}merged ${1}
}

# Check if branches are merged together
git_branch_merged() {
  local A="${1:-HEAD}"
  local B="${2:-HEAD}"
  git branch --merged "$A" | grep "$B" >/dev/null ||
  git branch --merged "$B" | grep "$A" >/dev/null
}

########################################
# Get remote url
git_url() {
  git ${2:+--git-dir="$2"} config --get remote.${1}.url
}
git_urls() {
  for REMOTE in $(git_remotes "$1"); do
    git ${1:+--git-dir="$1"} config --get remote.${REMOTE}.url
  done
}

# Check if a repo has been modified
# https://stackoverflow.com/questions/5139290/how-to-check-if-theres-nothing-to-be-committed-in-the-current-branch
git_modified() {
  #! git ${1:+--git-dir="$1"} diff-files --quiet --ignore-submodules || ! git ${1:+--git-dir="$1"} diff-index --cached --quiet --ignore-submodules HEAD --
  ! git ${1:+--git-dir="$1"} diff --quiet || ! git ${1:+--git-dir="$1"} diff --cached --quiet
}

# Check if repo has untracked files
git_untracked() {
  [ "$(git ${1:+--git-dir="$1"} ls-files --other --exclude-standard --directory)" != "" ]
}

# Git status for scripts
git_st() {
  #git ${2:+--git-dir="$2"} status -s | awk '/^[\? ]?'$1'[\? ]?/ {print "\""$2"\""}'
  #git ${2:+--git-dir="$2"} status -s | awk '/'"^[\? ]?$1"'/{print substr($0,4)}'
  git ${3:+--git-dir="$3"} status -s --porcelain --untracked ${2:+"$2"} | awk '/^^[\? ]?'$1'/{print $2}'
}
git_stx() {
  git ${3:+--git-dir="$3"} status -z ${2:+"$2"} | awk 'BEGIN{RS="\0"; ORS="\0"}/'"^[\? ]?$1"'/{print substr($0,4)}'
}

# Files status in a commit
git_ls_in_ref() {
  git diff-tree --no-commit-id --name-status -r "${2:-HEAD}" | awk "/^($1)/ {print \$2}"
}
git_ls_deleted_in_ref()  { git_ls_in_ref D "$@"; }
git_ls_created_in_ref()  { git_ls_in_ref A|C "$@"; }
git_ls_updated_in_ref()  { git_ls_in_ref R|T "$@"; }
git_ls_modified_in_ref() { git_ls_in_ref M "$@"; }

# List files by action (A=added, D=deleted, M=modified)
#~ git_filter_by_status() {
  #~ local FILTER="${1:?No status filter ADM specified...}"
  #~ local STATUS="${2:?No file status ADM specified...}"
  #~ shift 2
  #~ git diff-tree -r "${@:-HEAD}" --diff-filter=$FILTER --raw | awk '
    #~ function basename(file) {
      #~ sub(".*/", "", file)
      #~ return file
    #~ }
    #~ {
      #~ # Get parameters
      #~ hash=$3 $4
      #~ action=$5
      #~ file=$6
      #~ sub("    ", "", file)
      #~ name=basename(file)
      #~ # Filter files, reject already seen ones
      #~ if ((hash in seen) || (name in seen)) {
        #~ delete validated[hash]
        #~ delete validated[name]
      #~ } else if (action == "'$STATUS'") {
        #~ validated[hash]=file
      #~ }
      #~ seen[hash]=file
      #~ seen[name]=file
    #~ }
    #~ END {
      #~ for (x in validated) {
        #~ print validated[x]
      #~ }
    #~ }
  #~ '
#~ }
#~ git_deleted() { git_filter_by_status AD D "$@"; }
#~ git_created() { git_filter_by_status AD A "$@"; }
#~ git_updated() { git_filter_by_status DM M "$@"; }
#~ git_modified() { git_filter_by_status M M "$@"; }

# Get remote names
git_remotes() {
  #~ git ${2:+--git-dir="$2"} remote -v | awk '$3 ~ /(fetch)/ {print $1}' | grep -E "$1" | xargs sh -c 'test $# -gt 0 && echo "$@"' _
  git ${2:+--git-dir="$2"} remote -v | awk 'BEGIN {ret=1} $1 ~ /'$1'/ && $3 ~ /(fetch)/ {if (ret==0){printf " "}; printf $1; ret=0} END {exit ret}'
}

# Is remote a valid git repo ?
git_remote_valid() {
  git ${2:+--git-dir="$2"} config --get "remote.$1.fetch" >/dev/null
}

# Get git backup name
git_name() {
  echo "$(git_repo).${1:+$1.}$(uname -n).$(git_branch | tr '/' '_').$(date +%Y%m%d-%H%M%S).$(git_shorthash)${2:+.$2}"
}

# Check a set of commands exist
git_cmd_exists() {
  local EXECPATH="$(git_exp)"
  local CMD
  for CMD; do
    [ -x "${EXECPATH}/git-${CMD}" ] || return 1
  done
  return 0
}

# Check a remote repo exists
git_ping() {
  git ${2:+--git-dir="$2"} ls-remote "${1:-$(git_dir)}" &> /dev/null
}

# Get number of commits
alias git_count_all='git_count --all'
git_count() {
  git ${2:+--git-dir="$2"} rev-list ${1:-HEAD} --count
}

# Check if we are in a detached head
git_detached() {
  [ -z "$(git ${1:+--git-dir="$1"} symbolic-ref --short -q HEAD)" ]
}

########################################
# Get hash
git_hash() {
  git ${2:+--git-dir="$2"} rev-parse --revs-only "${1:-HEAD}"
}
git_hash_all() {
  git ${2:+--git-dir="$2"} rev-list "${1:-HEAD}"
}
git_hash_root() {
  git ${2:+--git-dir="$2"} rev-list --max-parents=0 "${1:-HEAD}" 2>/dev/null ||
  git ${2:+--git-dir="$2"} rev-list --parents "${1:-HEAD}" | egrep --color=never "^[a-f0-9]{40}$"
}

# Get short hash (8 characters)
git_shorthash() {
  git_hash "$@" | cut -c 1-8
}
git_shorthash_all() {
  git_hash_all "$@" | cut -c 1-8
}
git_shorthash_root() {
  git_hash_root "$@" | cut -c 1-8
}

########################################
# Get commits author
git_author() {
  local REF
  for REF; do
    git log --format='%an <%ae>' "${REF}^!"
  done
}

# Show all authors commits
alias git_authors='git shortlog -s -n'
alias git_authors_all='git shortlog -s -n -a'

########################################
# Extract a path from a repo without cloning/checking it out
git_extract() {
  local REF="${1:-HEAD}"
  local SRC="${2:-.}"
  local DST="${3:-.}"
  local URL="$4"
  mkdir -p "$DST"
  git archive --format=tar ${URL:+--remote="$URL"} "$REF" ${SRC:+-- "$SRC"} | tar xv -C "$DST"
}

########################################

# Update local branches with checkout
#~ git_up() {
  #~ git_exists || return 1
  #~ git_modified && echo "Cannot run, repo is not clean..." && return 2
  #~ local REMOTES="${1:-$(git_remotes)}"
  #~ local BRANCHES="$2"
  #~ local CURRENT_REF="$(git symbolic-ref --short HEAD 2>/dev/null || git_hash)"
  #~ for REMOTE in $REMOTES; do
    #~ if git_remote_valid "$REMOTE"; then
      #~ echo -n "Pull from $REMOTE: "
      #~ for BRANCH in ${BRANCHES:-$(git_branch_remote "$REMOTE" | cut -d/ -f2-)}; do
        #~ if git_branch_exists "$BRANCH"; then
          #~ if [ "$(git_hash "refs/heads/$BRANCH")" != "$(git_hash "refs/remotes/$REMOTE/$BRANCH")" ]; then
            #~ git checkout "$BRANCH" &&
              #~ git_pull --ff-only "$REMOTE" "$BRANCH" || continue
          #~ else
            #~ echo "Skip already aligned $REMOTE/$BRANCH ..."
          #~ fi
        #~ else
          #~ git checkout --no-track "$REMOTE/$BRANCH" &&
            #~ git_pull --ff-only "$REMOTE" "$BRANCH" || continue
        #~ fi
      #~ done
    #~ fi
  #~ done
  #~ git checkout "$CURRENT_REF" 2>/dev/null
#~ }

# Update local branches without checkout
git_up() {
  local REMOTES="${1:-$(git_remotes)}"
  local BRANCHES="${2:-$(git_branch_remote "$REMOTE" | awk -F/ '{print $2}')}" # ${2:-$(git_branches)}
  local CUR_BRANCH="$(git_branch)"
  for REMOTE in $REMOTES; do
    for BRANCH in $BRANCHES; do
      if [ "$BRANCH" != "$CUR_BRANCH" ]; then
        echo -n "Update local branch $BRANCH from $REMOTE ... "
        git fetch "$REMOTE" "$BRANCH:$BRANCH" && echo "OK" || echo ""
      fi
    done
  done
}

# Update remote branches without checkout
git_up_remote() {
  local REMOTES="${1:-$(git_remotes)}"
  local BRANCHES="${2:-$(git_branches)}"
  git_update_branch "$@" &&
    for REMOTE in $REMOTES; do
      for BRANCH in $BRANCHES; do
        echo -n "Push to $REMOTE $BRANCH ... "
        git push "$REMOTE" "$BRANCH"
      done
    done
}

########################################
# Pull versions
if [ $(git_version) -gt $(git_version 2.9) ]; then
git_pull() { git pull --rebase --autostash "$@"; }
elif [ $(git_version) -ge $(git_version 1.7.10.4) ]; then
git_pull() { git pull --rebase "$@"; }
else
git_pull() { git pull "$@"; }
fi

# Pull current branch from all existing remotes
git_pull_all() {
  git_exists || return 1
  local REMOTES="${1:-$(git_remotes)}"
  shift $(($# > 1 ? 1 : $#))
  for REMOTE in $REMOTES; do
    if git_remote_valid "$REMOTE"; then
      echo -n "Pull from $REMOTE: "
      git_pull --ff-only "$REMOTE" "${@:-$(git_branch)}" || break
    fi
  done
}

########################################
# Push current branch to all existing remotes
alias git_push_all_all='git_push_all "" --all'
git_push_all() {
  git_exists || return 1
  local REMOTES="${1:-$(git_remotes)}"
  shift $(($# > 1 ? 1 : $#))
  for REMOTE in $REMOTES; do
    if git_remote_valid "$REMOTE"; then
      echo -n "Push to $REMOTE: "
      git push "$REMOTE" "${@:-$(git_branch)}"
    fi
  done
}

# Enable/disable push on a given remote(s)
git_push_disable() {
  for REMOTE in ${@:-$(git_remotes)}; do
    git remote set-url --push "$REMOTE" no-push
  done
}
git_push_enable() {
  for REMOTE in ${@:-$(git_remotes)}; do
    git config --unset "remote.${REMOTE}.pushurl" no-push
  done
}

########################################
# Sync local & remotes repo
git_sync() {
  git_up && git_push_all "" --all
}

########################################

# Secure file deletion
git_secure_delete() {
  echo "Remove file '$1'"
  { command -v shred >/dev/null && shred -fu "$1"; } ||
  { command -v wipe >/dev/null && wipe -f -- "$1"; } ||
  rm -- "$1"
}

# Create a bundle
git_bundle() {
  # Main
  (
  local -; set -e
  git_exists || return 1
  local PREFIX="${6:-$(git_repo).$(uname -n)}"
  local SUFFIX="${7:-$(git_shorthash).bundle}"
  local NAME="${PREFIX}.$(date +%Y%m%d-%H%M%S).${SUFFIX}"
  local OUT="${1:-$(git_user_dir)/bundle/${NAME}}"
  [ -z "${OUT##*/}" ] && OUT="${OUT%/*}/${NAME}"
  OUT="${OUT%%.xz}"; OUT="${OUT%%.git}.git"
  local OUTBASE="$OUT"
  local GPG_RECIPIENT="$2"
  local PAR2_RECOVERY="$3"
  local OWNER="${4:-$USER}"
  local XZOPTS="$5"
  shift $(($# > 7 ? 7 : $#))
  if ! mkdir -p "$(dirname "$OUT")"; then
    echo "Cannot create directory '$(dirname "$OUT")'. Abort..."
    return 2
  fi
  echo "Bundle into $OUT"
  # Bundle option --all should be equivalent to --branches --tags --remotes
  if [ $(git_version) -le $(git_version 2.20.1) ]; then
    git bundle create "$OUT" ${@:---all}
  else
    git bundle create -q "$OUT" ${@:---all}
  fi
  echo "Compress into ${OUT}.xz"
  xz -k -z -S .xz --verbose $XZOPTS "$OUT" &&
    git_secure_delete "$OUT"
  OUT="${OUT}.xz"
  chown "$OWNER" "$OUT"
  if [ -n "$GPG_RECIPIENT" ]; then
    echo "Encrypt bundle into ${OUT}.gpg"
    gpg -v --output "${OUT}.gpg" --encrypt --trust-model always --recipient "$GPG_RECIPIENT" "${OUT}" &&
      git_secure_delete "${OUT}"
    OUT="${OUT}.gpg"
    chown "$OWNER" "$OUT"
  fi
  if [ -n "$PAR2_RECOVERY" ]; then
    PAR2_RECOVERY="$(expr 1 "*" "$PAR2_RECOVERY" 2>/dev/null || echo 0)"
    PAR2_RECOVERY="$(($PAR2_RECOVERY < 5 ? 5 : $PAR2_RECOVERY))"
    echo "Create PAR2 files for '$OUT' (${PAR2_RECOVERY}% recovery)"
    par2 create -r${PAR2_RECOVERY} "$OUT"
  fi
  ls -l "${OUTBASE}"*
  )
}

# Create an incremental bundle
git_incbundle() {
  local -; set -e
  git_exists || return 1
  local TAGNAME="$(basename "${1:-incbundle.$(uname -n)}")"
  [ $# -ge 1 ] && shift
  local PREV="$(git_shorthash "${TAGNAME}")"
  local NEXT="$(git_shorthash)"
  if [ -n "$PREV" ]; then
    if [ "$PREV" = "$NEXT" ]; then
      echo "New incremental bundle from ${TAGNAME} ($PREV) to HEAD ($NEXT) would be empty. Skip it..."
      return 0
    else
      echo "Make incremental bundle from ${TAGNAME} ($PREV) to HEAD ($NEXT)"
      local NAME="${PREV}.${NEXT}.bundle.inc"
      git_bundle "$1" "$2" "$3" "$4" "$5" "$6" "$NAME" --branches --tags "${TAGNAME}~1.." ||
        return $?
    fi
  else
    echo "Make initial full bundle up to HEAD ($NEXT)"
    local NAME="${NEXT}.bundle.full"
    git_bundle "$1" "$2" "$3" "$4" "$5" "$6" "$NAME" --branches --tags ||
      return $?
  fi
  # Set tag
  git tag -f "${TAGNAME}" "HEAD"
}

# Reset incremental bundles chain; next bundle will be full
git_incbundle_reset() {
  local TAGNAME="$(basename "${1:-incbundle.$(uname -n)}")"
  git tag -d "${TAGNAME}"
}

# Recreate all remotes refs from a bundle file
git_bundle_import_remote_refs() {
  for BUNDLE; do
    git bundle list-heads "$BUNDLE" |
      while read SHA REF; do
        echo + git update-ref "$REF" "$SHA"
        git update-ref "$REF" "$SHA"
      done
  done
}

# Git bundle recursive
# https://github.com/xeyownt/git-subundle/blob/master/git-subundle
git_recbundle() {
  find ./ -name .git -print0 | xargs -r0 -- sh -c '
    . ~/.rc.d/40_git.sh
    for DIR; do
      cd "$HOME/.vim/bundle/$(dirname "$DIR")"
      pwd
      git_bundle "$HOME/.vim/bundle/"
    done
  ' _
}

########################################

# Git upkeep
git_upkeep() {
  local DBG=""
  local NEW=""
  local DEL=""
  local COMMIT=""
  local MSG="git_upkeep() at $(date +%Y%m%d-%H%M%S)"
  local PULL=""
  local PUSH=""
  local REMOTES=""
  # Get arguments
  while getopts "andcpur:m:zh" OPTFLAG; do
    case "$OPTFLAG" in
      a) NEW=1; DEL=1;;
      n) NEW=1;;
      d) DEL=1;;
      c) COMMIT=1;;
      m) MSG="$OPTARG";;
      p) PULL=1;;
      u) PUSH=1;;
      r) REMOTES="$OPTARG";;
      z) set -vx; DBG="true";;
      *) echo >&2 "Usage: git_upkeep [-a] [-n] [-d] [-c] [-p] [-u] [-r 'remotes'] [-m 'msg'] [-z]"
         echo >&2 "-a stage (a)ll files"
         echo >&2 "-n stage (n)ew files"
         echo >&2 "-d stage (d)eleted files"
         echo >&2 "-c (c)ommit files"
         echo >&2 "-p (p)ull"
         echo >&2 "-u p(u)sh"
         echo >&2 "-r (r)remotes to pull/push"
         echo >&2 "-m commit (m)essage"
         echo >&2 "-z simulate operations"
         return 1
         ;;
    esac
  done
  shift "$((OPTIND-1))"
  unset OPTFLAG OPTARG
  OPTIND=1
  [ $# -ne 0 ] && echo "Bad parameters: $@" && return 1
  # Main
  git_exists || return 1
  # Force PULL if a remote is using gcrypt
  if [ -z "$PULL" ] && [ -n "$PUSH" ] && git_gcrypt_remotes $REMOTES; then
    echo "Force pull because of gcrypt remote(s)"
    PULL=1
  fi
  # Add
  if [ -n "$DEL" ]; then
      git_stx "^D[ M]|^ D" | xargs -r0 $DBG git add --all --ignore-error --
  fi
  if [ -n "$NEW" ]; then
      $DBG git add -u || return $?
  fi
  # Commit
  if [ -n "$COMMIT" ]; then
      $DBG git commit -m "$MSG" || return 0 # return 0 when nothing to be committed
  fi
  # Pull
  if [ -n "$PULL" ]; then
    for REMOTE in ${REMOTES:-""}; do
      $DBG git pull --rebase $REMOTE || return $?
    done
  fi
  # Push
  if [ -n "$PUSH" ]; then
    for REMOTE in ${REMOTES:-""}; do
      $DBG git push $REMOTE || return $?
    done
  fi
}

########################################
# Normal to bare repo
git_tobare() {
  local DIR="${1:-$PWD}"
  local TMP="${DIR}.git"
  git_exists "$DIR/.git" &&
  mv "$DIR/.git" "$TMP" &&
  rm -r "$DIR" &&
  mv "$TMP" "$DIR" &&
  command cd . &&
  git --git-dir="$DIR" config --bool core.bare true
}

# Bare to normal repo
git_frombare() {
  local DIR="${1:-$PWD}"
  git_exists "$DIR" &&
  mkdir -p "$DIR/.git" &&
  mv "$DIR"/* "$DIR/.git" &&
  git --git-dir="$DIR/.git" config --bool core.bare false &&
  git --git-dir="$DIR/.git" --work-tree="$DIR" reset --hard HEAD --
}

########################################
# Git diff all files
git_diff_all() {
  git diff "$@" 2>/dev/null
  git diff --cached "$@"
}
# Git diff all files with meld
git_diffm_all() {
  git difftool -y "$@" 2>/dev/null
  git difftool --cached -y "$@"
}

########################################

# Backup stashes in .git/backup
#git stash list --pretty=format:"%h %gd %ci" | awk '{gsub(/-/,"",$3); gsub(/:/,"",$4); print "stash{" $3 "-" $4 "}_" $1}'
git_stash_backup() {
  git_exists || return 1
  local DST="$(git_user_dir)/stash"
  local IFS="$(printf '\n')"
  mkdir -p "$DST"
  git stash list --format="%H %h %s" | while IFS=" " read -r HASH SHORT NAME; do
    NAME="$(echo "$NAME" | awk -F: '{gsub(/^ */,"",$2); gsub(/ /,"_",$2);print $2}' | cut -c -80)"
    local FILE="$DST/stash_${SHORT}_head_${NAME}.gz"
    if [ ! -e "$FILE" ]; then
      echo "Backup $HASH in $FILE"
      git stash show -p "$HASH" "$@" | gzip --best > "$FILE"
    fi
  done
}

# Get stash name by index
git_stash_name() {
  git stash list | awk "NR==$((${1:-0}+1)){print \$2}"
}

###
# Push changes onto stash, keep them
if [ $(git_version) -ge 2000000 ]; then

git_stash_create() {
  local MSG="$(git_name)${1:+.$1}"
  git stash store -m "$MSG" "$(git stash create)"
}

else # git_version

git_stash_create() {
  local MSG="$(git_name)${1:+.$1}"; shift 2>/dev/null
  if [ $(git stash list | wc -l) -eq 0 ]; then
    git stash save -q "$MSG" &&
    git stash apply -q
  else
    local REF="$(git stash create)"
    : "${REF:?Nothing to stash...}"
    git stash store -m "$MSG" "$REF" 2>/dev/null ||
      git update-ref -m "$MSG" refs/stash "$REF"
  fi
}

fi # git_version

###
# Push changes onto stash, revert them
if [ $(git_version) -ge 2000000 ]; then

git_stash_save() {
  local MSG="$(git_name)${1:+.$1}"; shift 2>/dev/null
  git stash push -m "$MSG" "$@"
}
git_stash_save_all() {
  local MSG="$(git_name)${1:+.$1}"; shift 2>/dev/null
  git stash push --all -m "$MSG" "$@"
}
git_stash_save_untracked() {
  local MSG="$(git_name)${1:+.$1}"; shift 2>/dev/null
  git stash push --untracked -m "$MSG" "$@"
}

else # git_version

git_stash_save() {
  local MSG="$(git_name)${1:+.$1}"; shift 2>/dev/null
  git stash save "$MSG" "$@"
}
git_stash_save_all() {
  local MSG="$(git_name)${1:+.$1}"; shift 2>/dev/null
  git stash save --all "$MSG" "$@"
}
git_stash_save_untracked() {
  local MSG="$(git_name)${1:+.$1}"; shift 2>/dev/null
  git stash save --untracked "$MSG" "$@"
}

fi # git_version

###
# Show diff between stash and local copy
git_stash_diff() {
  local STASH="${1:-0}"; shift 2>/dev/null
  git diff "stash@{$STASH}" "$@"
}
git_stash_diffm() {
  local STASH="${1:-0}"; shift 2>/dev/null
  git difftool -y "stash@{$STASH}" "$@" 
}
git_stash_diffl() {
  git_stash_diff "${@:-0}" --name-only
}

###
# Force apply changes
git_stash_apply_forced() {
  git stash show -p "$@" | git apply
}

# Force pop changes
git_stash_pop_forced() {
  git_stash_apply_forced "$@" && git stash drop "$@"
}

# Pop in a new branch
git_stash_pop_branch() {
  git stash branch "$(git_stash_name "${1:-0}")" "stash@{${1:-0}}"
}

###
# Show stash file list
git_stash_ls() { git stash show "$@"; }

# Show stash file content
git_stash_cat() { git stash show -p "$@"; }

# Show stash history
git_stash_history() {
  local START="${1:-0}"
  local END="${2:-$(($(git stash list | wc -l) - 1))}"
  for NUM in $(seq $START $(($END>$START ? $END : $START))); do
    git stash show $NUM
    git stash show -p $NUM
    echo "------"
    echo
  done
}

########################################
# Clean repo back to given CL
# remove unversionned files
alias git_clean='PROCEED= BACKUP= _git_clean'
_git_clean() {
  git_exists || return 1
  # Confirmation
  if [ "$PROCEED" != "-y" ]; then
    git clean -d -n --exclude=".*" "$@"
    ! ask_question "Proceed? (y/n) " y Y >/dev/null && return 0
  fi
  # Backup
  if [ "$BACKUP" != "-y" ] && ask_question "Backup? (y/n) " y Y >/dev/null; then
    local DST="$(git_user_dir)/clean"
    mkdir -p "$DST"
    git_stx '??' | xargs -0 7z a "$DST/clean.$(git_name).7z"
  fi
  # Clean repository
  git clean -d -f --exclude=".*" "$@"
}

########################################
# List local files
git_ls() {
  #git ${3:+--git-dir="$3"} ls-tree -r ${1:-$(git_branch "" "$3")} --name-only ${2:+| grep -F "$2"}
  git ls-files "$@"
}
git_lsx() {
  git ls-files -z "$@"
}

# List files in commit
git_ls_commit() {
  #git show --pretty="format:" --name-only "${@:-HEAD}"
  #git ${2:+--git-dir="$2"} diff-tree --no-commit-id --name-only -r "${1:-HEAD}"
  git diff-tree --no-commit-id --name-only -r "${@:-HEAD}"
}

# List binary files in commit/rev
# https://stackoverflow.com/questions/30689384/find-all-binary-files-in-git-head
git_ls_bin() {
  local REVLIST="$1"
  [ "$REVLIST" = "all" ] && REVLIST="$(git rev-list --all | xargs)" ||
  [ "$REVLIST" = "branches" ] && REVLIST="$(git rev-list --branches | xargs)" ||
  [ "$REVLIST" = "tags" ] && REVLIST="$(git rev-list --tags | xargs)"
  if [ -z "$REVLIST" ]; then
    bash -c 'comm -13 <(git grep -Il "" $1 -- | sort -u) <(git grep -al "" $1 -- | sort -u)' _ "$REVLIST" | xargs -r du -hc | sort -h
  else
    bash -c 'comm -13 <(git grep -Il "" $1 -- | sort -u) <(git grep -al "" $1 -- | sort -u)' _ "$REVLIST"
  fi
}

# List all ignored files search patterns
git_ls_ignored() {
  find . ~/.gitignore .git/info/exclude -name '*gitignore' -exec cat {} + 2>/dev/null | less
}

# Cat a file
git_cat() {
  #git show ${1:-HEAD}:"$2"
  local REV="${1:-HEAD}"
  shift 2>/dev/null
  for FILE in "${@:-}"; do
    git show ${REV}:"$FILE"
  done
}

########################################
# Subtrees
# See https://developer.atlassian.com/blog/2015/05/the-power-of-git-subtree/
# Merge 1 repo as a subtree of current repo
git_subtree_add() {
  local REPO="${1:?No remote repository specified}"
  local PREFIX="${2:?No local destination specified}"
  local REF="${3:-master}"
  git subtree add --prefix="$PREFIX" "$REPO" "$REF" --squash
}

# Merge 1 repo as a subtree of current repo
git_subtree_update() {
  local REPO="${1:?No remote repository specified}"
  local PREFIX="${2:?No local destination specified}"
  local REF="${3:-master}"
  git subtree pull --prefix="$PREFIX" "$REPO" "$REF" --squash
}

########################################
# https://git-scm.com/book/en/v2/Git-Tools-Rewriting-History
# https://git-scm.com/docs/git-filter-branch

# Amend author/committer names & emails
git_amend_names() {
(
  # Run in a subshell because we need to export lots of variables
  # Identify who/what the amend is about
  export AUTHOR_1="${1%%:*}"
  export AUTHOR_2="${1##*:}"
  export AUTHOR_EMAIL_1="${2%%:*}"
  export AUTHOR_EMAIL_2="${2##*:}"
  export AUTHOR_DATE_1="${3%%:*}"
  export AUTHOR_DATE_2="${3##*:}"
  export COMMITTER_1="${4%%:*}"
  export COMMITTER_2="${4##*:}"
  export COMMITTER_EMAIL_1="${5%%:*}"
  export COMMITTER_EMAIL_2="${5##*:}"
  export COMMITTER_DATE_1="${6%%:*}"
  export COMMITTER_DATE_2="${6##*:}"
  local REV="${7:-HEAD}"
  # Display what is going to be done
  [ ! -z "$AUTHOR_1" ] && echo "Replace author name '$AUTHOR_1' by '$AUTHOR_2'"
  [ ! -z "$AUTHOR_EMAIL_1" ] && echo "Replace author email '$AUTHOR_EMAIL_1' by '$AUTHOR_EMAIL_2'"
  [ ! -z "$AUTHOR_DATE_1" ] && echo "Replace author date '$AUTHOR_DATE_1' by '$AUTHOR_DATE_2'"
  [ ! -z "$COMMITTER_1" ] && echo "Replace committer name '$COMMITTER_1' by '$COMMITTER_2'"
  [ ! -z "$COMMITTER_EMAIL_1" ] && echo "Replace committer email '$COMMITTER_EMAIL_1' by '$COMMITTER_EMAIL_2'"
  [ ! -z "$COMMITTER_DATE_1" ] && echo "Replace committer date '$COMMITTER_DATE_1' by '$COMMITTER_DATE_2'"
  read -p "Press enter to go on..."
  # Define the replacement script
  local SCRIPT='
    STATUS="no change"
    if [ ! -z "$AUTHOR_1" -a "$AUTHOR_1" = "$GIT_AUTHOR_NAME" ]; then export GIT_AUTHOR_NAME="$AUTHOR_2"; STATUS="updated"; fi
    if [ ! -z "$AUTHOR_EMAIL_1" -a "$AUTHOR_EMAIL_1" = "$GIT_AUTHOR_EMAIL" ]; then export GIT_AUTHOR_EMAIL="$AUTHOR_EMAIL_2"; STATUS="updated"; fi
    if [ ! -z "$AUTHOR_DATE_1" -a "$AUTHOR_DATE_1" = "$GIT_AUTHOR_DATE" ]; then export GIT_AUTHOR_DATE="$AUTHOR_DATE_2"; STATUS="updated"; fi
    if [ ! -z "$COMMITTER_1" -a "$COMMITTER_1" = "$GIT_COMMITTER_NAME" ]; then export GIT_COMMITTER_NAME="$COMMITTER_2"; STATUS="updated"; fi
    if [ ! -z "$COMMITTER_EMAIL_1" -a "$COMMITTER_EMAIL_1" = "$GIT_COMMITTER_EMAIL" ]; then export GIT_COMMITTER_EMAIL="$COMMITTER_EMAIL_2"; STATUS="updated"; fi
    if [ ! -z "$COMMITTER_DATE_1" -a "$COMMITTER_DATE_1" = "$GIT_COMMITTER_DATE" ]; then export GIT_COMMITTER_DATE="$COMMITTER_DATE_2"; STATUS="updated"; fi
    echo " => $STATUS"
  '
  # Execute the script
  git filter-branch -f --env-filter "$SCRIPT" $REV
)
}

# Amend commit log (with git filter-branch).
git_amend_log() {
  ( set -e
    local FROM="$(git_hash ${1:?No SHA1_1 specified...})"
    local NEWLOG="${2:?No new log specified...}"
    local TO="${3:-$(git_branch)}"
    local BRANCH="${4:-$(git_branch)}"
    git_modified && return 1
    #git_tag_create "git_amend_log"
    git branch _tmp_git_amend_log "${TO}"
    local SCRIPT="if [ \"\$GIT_COMMIT\" = \"$FROM\" ]; then echo \"$NEWLOG\"; else cat; fi"
    git filter-branch -f --msg-filter "$SCRIPT" -- ${FROM}^.._tmp_git_amend_log || true
    echo "Previous head was: $(git_hash)"
    git update-ref refs/heads/"$BRANCH" refs/heads/_tmp_git_amend_log
    git branch -d _tmp_git_amend_log
  )
}

# Amend commit file (with git filter-branch).
git_amend_file() {
  ( set -e
    local FROM="$(git_hash ${1:?No SHA1_1 specified...})"
    local TO="${2:-$(git_branch)}"
    local BRANCH="${3:-$(git_branch)}"
    ! git_modified && return 1
    git stash
    git branch _tmp_git_amend_log "${TO}"
    local SCRIPT="git stash show -p | git apply"
    git filter-branch -f --tree-filter "$SCRIPT" -- ${FROM}.._tmp_git_amend_log || true
    echo "Previous head was: $(git_hash)"
    git update-ref refs/heads/"$BRANCH" refs/heads/_tmp_git_amend_log
    git branch -d _tmp_git_amend_log
    git stash pop
  )
}

########################################
# https://git-scm.com/book/en/v2/Git-Internals-Maintenance-and-Data-Recovery

# Prune a given file from history
git_purge_file() {
  local FILE="${1:?No path specified...}"
  git filter-branch --force --index-filter \
    "git rm --cached --ignore-unmatch '$FILE'" \
    --prune-empty --tag-name-filter cat -- --all
}

# Purge commits from a given author
git_purge_author() {
  local NAME="${1:?No name specified...}"
  local REV="${2:-HEAD}"
  git filter-branch --commit-filter \
    'if [ "$GIT_AUTHOR_NAME" = "$NAME" ]; then skip_commit "$@"; else git commit-tree "$@"; fi' \
    "$REV"
}

# Various cleanup fcts
# https://stackoverflow.com/questions/3797907/how-to-remove-unused-objects-from-a-git-repository/14729486#14729486
git_gc() {
  git -c gc.reflogExpire=0 -c gc.reflogExpireUnreachable=0 -c gc.rerereresolved=0 -c gc.rerereunresolved=0 -c gc.pruneExpire=now gc "$@"
}

# Forced garbage-collector (use after git_purge_file) 
git_gc_purge() {
  # Purge known remotes refs
  rm -rf .git/refs/remotes/ .git/*_HEAD
  # Remove git filter-branch backups
  rm -rf .git/refs/original/ .git/logs/
  git for-each-ref --format="%(refname)" refs/original/ | \
    xargs -n1 --no-run-if-empty git update-ref -d
  # Fsck
  git fsck
  # Cleanup reflog & prune
  git reflog expire --expire-unreachable="${1:-now}" --all
  git gc --prune="${1:-now}"
}

########################################

# Repack with different memory usage settings
git_repack_all() {
  if [ -z "$1" ]; then
    git ${2:+--git-dir="$2"} repack -a -d -l
  elif [ "$1" = "low" ]; then
    git ${2:+--git-dir="$2"} repack -a -d -l --threads=1 --window=3 --depth=25 --window-memory=32m --max-pack-size=32m
  elif [ "$1" = "medium" ]; then
    git ${2:+--git-dir="$2"} repack -a -d -l --threads=2 --window=10 --depth=50 --window-memory=256m --max-pack-size=256m
  elif [ "$1" = "high" ]; then
    git ${2:+--git-dir="$2"} repack -a -d -l --threads=4 --window=10 --depth=50 --window-memory=1g --max-pack-size=1g
  fi
}

# Truncate history from a given commit
# Warning: it rewrites everything
git_truncate() {
  echo "${1:?No commit specified}" > "$(git_dir)/info/grafts"
  echo "Check the repo history. Go on ? (enter/ctrl-c)"
  read
  git filter-branch --tag-name-filter cat -- --all
}

########################################
# List blob files & sizes
# https://gist.github.com/magnetikonline/dd5837d597722c9c2d5dfa16d8efe5b9
git_ls_blobs() {
	local IFS=$'\n'
	local SHA
	local TMPFILE="$(eval mktemp ${1:+-t -p "$1"})"
  trap "rm \"$TMPFILE\"; trap - INT TERM QUIT EXIT" INT TERM QUIT EXIT

  # List all blobs
	for SHA in $(git rev-list --all); do
    git ls-tree -r --long "$SHA" >> "$TMPFILE"
	done

	# Sort files by SHA1, de-dupe list and finally re-sort by filesize
	sort --key 3 "$TMPFILE" |
		uniq |
		sort --key 4 --numeric-sort --reverse
}
git_inspect_pack() {
  for PACKFILE; do
    echo "Inspecting packfile '$PACKFILE'"
    git verify-pack -v "$PACKFILE" | awk '/blob/{print $1}' | xargs -r -- sh -c '
      echo "Processing blobs $@"
      git rev-list --objects --all "$@"
    ' _
  done
}

########################################
# Git add gitignore
git_ignore_add() {
  grep "$1" .gitignore >/dev/null || echo "$1" >>.gitignore
}

# Git list gitignore
git_ignore_list() {
  git status -s --ignored 2>/dev/null || git clean -ndX
}

########################################

# Create a new branch from current one
# with a single commit in it
git_split() {
  git branch "${1:?No branch name specified}" $(echo "${2:-Initial commit.}" | git commit-tree HEAD^{tree})
}

########################################
# https://stackoverflow.com/questions/4479960/git-checkout-to-a-specific-folder
# Export the whole repo
git_backup() {
  local DST="${1:-$(git_user_dir)/backup/backup.$(git_name)}"
  shift
  # The last '/' is important
  git checkout-index -a -f --prefix="$DST/" "$@"
  7z a "${DST}.7z" "$DST" && rm -rf "$DST"
}

# Export a directory
git_backupdir() {
  local SRC="${1:?No input directory specified}"
  shift
  find "$SRC" -print0 | git_backup "$@" -f -z --stdin
}

########################################
# Store repo metadata
git_meta_store() {
  git-cache-meta --store && 
    git add "$(git_user_dir)/cache_meta" -f
}

# Reset file permissions
git_perms_reset() {
  git diff -p \
      | grep -E '^(diff|old mode|new mode)' \
      | sed -e 's/^old/NEW/;s/^new/old/;s/^NEW/new/' \
      | git apply
}

########################################
# Display commit graph
git_graph() {
  git log --graph --pretty=format:'%C(blue)%h - %C(bold cyan)%an %C(bold green)(%ar)%C(bold yellow)%d%n''          %C(bold red)%s%C(reset)%n''%w(0,14,14)%b' "$@"
}

# Search for a string in all the commits
git_grep_all() {
  # git log -S "$@" --source --all
  # git grep "$@" $(git rev-list --all) # Can report error: line too long
  git rev-list --all | xargs git grep "$@"
}

# Show history
alias git_history='git log -p'

# Show files in history by status
git_log_added() {
  git diff --name-only --diff-filter=A "${@:-HEAD~1..HEAD}"
}
git_log_removed() {
  git diff --name-only --diff-filter=D "${@:-HEAD~1..HEAD}"
}
git_log_modified() {
  git diff --name-only --diff-filter=M "${@:-HEAD~1..HEAD}"
}

# Select a commit using fzf
git_log_fzf() {
  local NUM="${1:-50}"
  local DEFAULT="${2:-HEAD}"
  if command -v fzf >/dev/null && [ $# -le 2 ]; then
    git log -n "$NUM" --pretty=format:'%h %s' --no-merges | fzf --no-sort | cut -c -7
  else
    echo "${3:-$DEFAULT}"
  fi
}

########################################
# Find git repo
git_find0_repo() {
  ## Bash only (read -d)
  #ff_git0 "${1:-.}" |
  # while IFS= read -r -d $'\0' DIR; do
  #   git_exists "$DIR" && printf "%s\0" "$DIR"
  # done
  for DIR in "${@:-.}"; do
    find ${DIR:-.} -type d -name '*.git' -prune -exec sh -c '
      for DIR; do
        git --git-dir="$DIR" rev-parse >/dev/null 2>&1 && printf "%s\0" "$DIR"
      done
    ' _ {} +
  done
}
git_find_repo() {
  git_find0_repo "$@" | xargs -r0
}

# Find git repo backward
# Similar to git_worktree but does not stop until it reaches /
git_findb0_repo() {
  for DIR in "${@:-.}"; do
    DIR="$(readlink -m "$DIR")"
    while [ "$DIR" != "/" ]; do
      if git --git-dir="$DIR" rev-parse >/dev/null 2>&1 ||
         git --git-dir="$DIR/.git" rev-parse >/dev/null 2>&1; then
        printf "%s\0" "$DIR"
      fi
      DIR="$(dirname "$DIR")"
    done
  done
}
git_findb_repo() {
  git_findb0_repo "$@" | xargs -r0
}

# Find binary files in history
# https://stackoverflow.com/questions/27931520/git-find-all-binary-files-in-history
alias git_history_bin='git_find_bin'
git_find_bin() {
  git log --all --numstat | grep '^-' | cut -f3 | sed -r 's|(.*)\{(.*) => (.*)\}(.*)|\1\2\4\n\1\3\4|g ; s|(.*) => (.*)|\1\n\2|g ; s|//|/|g' | sort -u
}

########################################
# Create a tag
git_tag_create() {
  git tag "tag_$(date +%Y%m%d-%H%M%S).${2:-$(git_branch)}${1:+_$1}" ${2:+"$2"}
}

# Delete a tag totally (local & remotes)
git_tag_delete() {
  local REMOTES="$(git_remotes)"
  git tag -l "$@" | xargs -rn 1 -I{} sh -c '
    TAG="$1"; shift
    for REMOTE; do
      git push "$REMOTE" :refs/tags/${TAG} || exit 1
    done
    git tag -d "$TAG"
  ' _ {} $REMOTES
}

# Get last created tags
git_tag_last() {
  eval git ${2:+--git-dir="$2"} tag --sort=-committerdate -l ${1:+ | head -n "$1"}
}

# Get previous tag in branch
git_tag_prev() {
  for FROM in "${@:-}"; do
    git describe --tags --abbrev=0 ${FROM:+${FROM}^}
  done
}

# Test tag existenz
git_tag_exists() {
  local REF="${1:?No ref specified...}"
  [ -n "$(git rev-parse --revs-only "$REF" 2>/dev/null)" ]
}

# List local tags not in remote at all
git_tag_local_only() {
  #comm -1 -3 <(git ls-remote --tags origin | cut -d$'\t' -f1 | sort) <(git show-ref --tags | cut -d' ' -f1 | sort)
  PIPE1="$(mktemp -u)"
  mkfifo "$PIPE1"
  PIPE2="$(mktemp -u)"
  mkfifo "$PIPE2"
  comm -2 -3 "$PIPE1" "$PIPE2" | uniq &
  git show-ref --tags | cut -d' ' -f2 | sort -u >"$PIPE1"
  git ls-remote --tags --refs "$@" | cut -d$'\t' -f2 | sort -u >"$PIPE2"
  wait
  rm "$PIPE1" "$PIPE2"
}

# Prune local tags not in remote at all
if [ $(git_version) -gt $(git_version 1.7.8) ]; then
  git_tag_remote_prune() {
    # Confirmation
    git fetch --dry-run --prune "${@:?No remote specified...}" "+refs/tags/*:refs/tags/*"
    ask_question "Proceed? (y/n) " y Y >/dev/null || return 0
    # Go !
    git fetch --prune "$@" "+refs/tags/*:refs/tags/*"
  }
else
  git_tag_remote_prune() {
    # Confirmation
    git_tag_local_only "$@"
    ask_question "Proceed? (y/n) " y Y >/dev/null || return 0
    # Go !
    git_tag_local_only "$@" | sed 's;refs/tags/;;' | xargs -r git tag -d
  }
fi

# Get tag date (creation date by default in %s format)
# https://stackoverflow.com/questions/13208734/get-the-time-and-date-of-git-tags
git_tag_date() {
	for TAG in "${@:-}"; do
		git for-each-ref --format="%(creatordate:format:${TAG_DATE_FORMAT:-%s})" refs/tags/${TAG}
	done
}

########################################
# Easy amend of previous commit
git_squash() {
  git_modified && return 1
  git_log_fzf 50 HEAD~1 "$@" | xargs -ro sh -c '
    LOG="$(git log --format=%B --reverse ${1}~1..HEAD)"
    git reset --soft "$1~1" &&
      git commit --edit -m "$LOG"
  ' _
}
git_fixup() {
  git_log_fzf 50 HEAD "$@" | xargs -ro sh -c '
    { ! git diff --quiet || ! git diff --cached --quiet; } &&
      git commit --fixup="$1" # Like --squash=
    git rebase --interactive --autosquash "${1}~1"
  ' _
}

########################################
# Rebasing
# https://stackoverflow.com/questions/15915430/what-exactly-does-gits-rebase-preserve-merges-do-and-why/50555740#50555740
git_rebase() {
  # Base options
  local OPTS="--interactive --rebase-merges"
  if [ $(git_version) -lt $(git_version 2.18) ]; then
    OPTS="--preserve-merges"
  fi
  # Add more options from command line
  while [ "${1##--}" != "$1" ]; do
    OPTS="${OPTS:+$OPTS }$1"
    shift
  done
  # Main
  git_log_fzf 250 HEAD "$@" | xargs -ro sh -c '
    git rebase $1 ${2}~1
  ' _ "$OPTS"
}

########################################
# Test if remote is using gcrypt
git_gcrypt_remotes() {
  for REMOTE; do
    git_url "$REMOTE" | grep '^gcrypt::' >/dev/null || return 1
  done
  return 0
}
git_gcrypt() {
  for DIR; do
    git --git-dir="$DIR" config core.gcrypt-id >/dev/null 2>&1 || return 1
  done
  return 0
}
git_gcrypt_url() {
  cd "$(mktemp -d)" || return 1
  for URL; do
    git-remote-gcrypt --check "$URL" >/dev/null 2>&1
    [ $? -ne 100 ] || return 1    
  done
  return 0
}

# Git clone gcrypt repo
git_clone_gcrypt() {
  local URL="${1:?No URL specified...}"
  local KEY="${2:?No key specified...}"
  local DIR="${3:-$(basename "$URL" .git)}"
  local REMOTE="${4:-origin}"
  local BRANCH="${4:-master}"
  ! git_exists "$DIR/.git" || return 1
  mkdir -p "$DIR"
  git --git-dir="$DIR/.git" init
  git --git-dir="$DIR/.git" remote add "$REMOTE" "gcrypt::${URL}"
  git --git-dir="$DIR/.git" config "remote.${REMOTE}.gcrypt-participants" "$KEY"
  (cd "$DIR"; git pull "$REMOTE" "$BRANCH")
}

# Git add gcrypt remote
git_add_gcrypt_remote() {
  local NAME="${1:?No remote name specified...}"
  local URL="${2:?No URL specified...}"
  local KEY="${3:?No key specified...}"
  local DIR="${4:-.}"
  git_exists "$DIR/.git" || return 1
  git --git-dir="$DIR/.git" remote add "$NAME" "gcrypt::${URL}"
  git --git-dir="$DIR/.git" config remote.${NAME}.gcrypt-participants "$KEY"
}

########################################
# https://gist.github.com/smileyborg/913fe3221edfad996f06
# Check if commit is an evil merge
git_evil_merge() {
  local SHA1="${1:?No commit specified...}"
  local GIT="${2:-$PWD}"
  local TMP="$(mktemp)"
  # Get current HEAD rev
  local HEAD="$(git -C "$GIT" symbolic-ref --short -q HEAD)" ||
  HEAD="$(git -C "$GIT" rev-parse HEAD)" # detached HEAD, get the SHA1
  # Stash changes
  local STASH="$(git -C "$GIT" stash 2>/dev/null)"
  # Perform the merge without resolving conflicts. Then diff the result with the actual merge commit we're inspecting.
  git -C "$GIT" checkout "${SHA1}~" &>/dev/null
  git -C "$GIT" -c merge.conflictstyle=diff3 merge --no-ff "${SHA1}^2" --no-commit &>/dev/null
  git -C "$GIT" add $(git -C "$GIT" status -s | cut -c 3-) &>/dev/null
  git -C "$GIT" commit --no-edit &>/dev/null
  git -C "$GIT" diff "HEAD..$SHA1" > "$TMP"
  # Restore repository
  git -C "$GIT" checkout "$HEAD" &>/dev/null
  # Restore stash
  [ -n "$STASH" ] && git -C "$GIT" stash pop
}

########################################
# Emulate git checkout --theirs/ours
# http://gitready.com/advanced/2009/02/25/keep-either-file-in-merge-conflicts.html
git_checkout_theirs() {
  git reset -- "$@"
  git checkout MERGE_HEAD -- "$@"
}
git_checkout_ours() {
  git reset -- "$@"
  git checkout ORIG_HEAD -- "$@"
}

########################################
# Repair broken repo; need a good one as reference
# https://git-annex.branchable.com/tips/recovering_from_a_corrupt_git_repository/
git_repair() {
  local - _
  local BAD="${1:?No bad repository specified...}"
  local GOOD="${2:?No good repository specified...}"
  set -e
  echo "Good repo: $GOOD"
  echo "Bad repo: $BAD"
  echo "Enter to go on, ctrl-c to cancel..."
  read _
  cd "$BAD"
  echo "$GOOD/.git/objects/" > .git/objects/info/alternates
  git repack -a -d
}

########################################
# Get hook samples
git_hook_samples() {
  local TMPDIR="$(mktemp -d)"
  git --git-dir="$TMPDIR" --bare init >/dev/null 2>&1
  echo "ls $TMPDIR/hooks"
  ls "$TMPDIR/hooks"
}

########################################
# Status aliases
alias gt='git status -uno'
alias gtu='gstu'
alias gst='git_st'
alias gst0='git_stx'
alias gstv='git_stx | xargs -0 $GEDITOR'
alias gstm='git status --porcelain -b | awk "NR==1 || /^(M.|.M)/"'    # modified
alias gsta='git status --porcelain -b | awk "NR==1 || /^A[ MD]/"'     # added
alias gstd='git status --porcelain -b | awk "NR==1 || /^D[ M]|^ D/"'  # deleted
alias gstr='git status --porcelain -b | awk "NR==1 || /^R[ MD]/"'     # renamed
#alias gstc='git status --porcelain -b | awk "NR==1 || /^C[ MD]/"'     # copied in index
alias gstc='git status --porcelain -b | awk "NR==1 || /^[DAU][DAU]/"' # unmerged = conflict
alias gstu='git status --porcelain -b | awk "NR==1 || /^\?\?/"'       # untracked = new
alias gsti='git status --porcelain -b | awk "NR==1 || /^\!\!/"'       # ignored
alias gstz='git status --porcelain -b | awk "NR==1 || /^[MARC] /"'    # in index
alias gsts='git status --porcelain -b | awk "NR==1 || /^[^\?\?]/"'    # not untracked
alias gstx='git_stx'
alias gstxm='git_stx "^(M.|.M)"'    # modified
alias gstxa='git_stx "^A[ MD]"'     # added
alias gstxd='git_stx "^D[ M]|^ D"'  # deleted
alias gstxr='git_stx "^R[ MD]"'     # renamed
#alias gstxc='git_stx "^C[ MD]"'     # copied in index
alias gstxc='git_stx "^[DAU][DAU]"' # unmerged = conflict
alias gstxu='git_stx "^\?\?"'       # untracked = new
alias gstxi='git_stx "^\!\!"'       # ignored
alias gstxz='git_stx "^[MARC] "'    # in index
alias gstxs='git_stx "^[^\?\?]"'    # not untracked# List aliases
# List files
alias gls='git ls-files'
alias glsm='git ls-files -m'
alias glsu='git ls-files -u' # unmerged = in conflict
alias glsd='git ls-files -d'
alias glsn='git ls-files -o --exclude-standard'
alias glsi='git ls-files -o -i --exclude-standard'
# Diff aliases
alias gd='git diff'
alias gdd='git diff'
alias gdm='git difftool -y'
alias gdt='git diff $(git_tracking)'
alias gdtc='git diff --cached $(git_tracking)'
alias gdmt='git difftool -y $(git_tracking)'
alias gdtl='git diff $(git_tag_last 1)'
alias gdtlm='git difftool -y $(git_tag_last 1)'
alias gda='git_diff_all'
alias gdda='git_diff_all'
alias gdma='git_diffm_all'
alias gdc='git diff --cached'
alias gddc='git diff --cached'
alias gdmc='git difftool -y --cached'
alias gdl='git diff --name-only'
alias gdlc='git diff --name-only --cached'
alias gdll='git diff --name-status'
alias gdllc='git diff --name-status --cached'
alias gds='git diff stash'
# Diff tree
alias gdta='git diff-tree --diff-filter=A --name-only -r ' #added
alias gdtc='git diff-tree --diff-filter=C --name-only -r ' #copied
alias gdtd='git diff-tree --diff-filter=D --name-only -r ' #deleted
alias gdtm='git diff-tree --diff-filter=M --name-only -r ' #modified
alias gdtr='git diff-tree --diff-filter=R --name-only -r ' #renamed
alias gdtt='git diff-tree --diff-filter=T --name-only -r ' #changed
alias gdtu='git diff-tree --diff-filter=Y --name-only -r ' #unmerged
alias gdtx='git diff-tree --diff-filter=X --name-only -r ' #unknown
alias gdtb='git diff-tree --diff-filter=B --name-only -r ' #broken
# Merge aliases
alias gmm='git mergetool -y'
#alias gmm='gstx UU | xargs -r0 -n1 git mergetool -y'
# Branch aliases
alias gba='git branch -a'   # list all
alias gbl='git branch -l'   # list local
alias gbv='git branch -v'   # verbose list local
alias gbvv='git branch -v'  # double-verbose list local
alias gbva='git branch -va' # verbose list all
alias gbav='git branch -va' # verbose list all
alias gbm='git branch --merged'    # list merged branches
alias gbM='git branch --no-merged' # list unmerged branches
alias gbr='git branch -r'   # list remote
alias gbag='git branch -a | grep'   # list all
alias gblg='git branch -l | grep'   # list local
alias gbvg='git branch -v | grep'   # verbose list local
alias gbvvg='git branch -v | grep'  # double-verbose list local
alias gbvag='git branch -va | grep' # verbose list all
alias gbavg='git branch -va | grep' # verbose list all
alias gbmg='git branch --merged | grep'    # list merged branches
alias gbMg='git branch --no-merged | grep' # list unmerged branches
alias gbrg='git branch -r | grep'   # list remote
alias gbagi='git branch -a | grep -i'   # list all
alias gblgi='git branch -l | grep -i'   # list local
alias gbvgi='git branch -v | grep -i'   # verbose list local
alias gbvvgi='git branch -v | grep -i'  # double-verbose list local
alias gbvagi='git branch -va | grep -i' # verbose list all
alias gbavgi='git branch -va | grep -i' # verbose list all
alias gbmgi='git branch --merged | grep -i'    # list merged branches
alias gbMgi='git branch --no-merged | grep -i' # list unmerged branches
alias gbrgi='git branch -r | grep -i'   # list remote
alias gbd='git branch -d'   # delete branch (merged only)
alias gbD='git branch -D'   # delete branch (any)
alias gbdr='git branch -rd' # remove remote branch (merged only)
alias gbDr='git push :'     # remove remote branch (any)
alias gbdro='git fetch -p'  # remote all old remotes
alias gbu='git branch --set-upstream-to '  # set branch upstream
alias gb='git branch'
# Tracking branches
alias gst='git_set_tracking'
alias ggt='git_tracking'
# Stash aliases
alias gsc='git_stash_create'
alias gss='git_stash_save'
alias gssa='git_stash_save_all'
alias gssu='git_stash_save_untracked'
alias gsp='git stash pop'
alias gspf='git_stash_pop_forced'
alias gspb='git_stash_pop_branch'
alias gsa='git stash apply'
alias gsaf='git_stash_apply_forced'
alias gsl='git stash list'
alias gslg='git stash list | grep'
alias gslgi='git stash list | grep -i'
alias gslc='git stash list | wc -l'
alias gsd='git_stash_diff'
alias gsdd='git_stash_diff'
alias gsdl='git_stash_diffl'
alias gsm='git_stash_diffm'
alias gsdm='git_stash_diffm'
alias gsf='git stash show'
alias gsls='git stash show'
alias gscat='git stash show -p'
# Gitignore aliases
alias gil='git_ignore_list'
alias gia='git_ignore_add'
# Commit aliases
alias gci='git commit'
alias gcim='git commit -m'
alias gcimw='git commit -m "wip on $(git_branch) the $(date)"'
alias gcims='git commit -m "squash this commit made on $(git_branch) the $(date)"'
alias gciam='git commit --amend'
alias gcam='git commit --amend'
alias gam='git commit --amend'
# Misc aliases
alias grm='git rm'
alias grmu='git clean -fn'
alias gmv='git mv'
# Hash
alias gha='git_hash'
alias ghar='git_roothash'
# Logs/history aliases
alias gl='git log --oneline'
alias glg='git log --oneline | grep'
alias glgi='git log --oneline | grep -i'
alias gla='git log --all'
alias glag='git log --all | grep'
alias glagi='git log --all | grep -i'
alias gln='git log --oneline -n'
alias gl1='git log --oneline -n 1'
alias gl2='git log --oneline -n 2'
alias gl3='git log --oneline -n 3'
alias gl5='git log --oneline -n 5'
alias gl10='git log --oneline -n 10'
alias gl25='git log --oneline -n 25'
alias glf='git diff-tree --no-commit-id --name-only -r'
alias glff='git log --follow'
alias gls='git log --stat'
alias glS='git log -S'
alias glt='git log --graph'
alias glh='git log -p'
alias glha='git log --pretty=format: --name-only --diff-filter=A | sort -u'
# Reflog
alias grl='git reflog'
alias grl1='git reflog -n 1'
alias grl2='git reflog -n 2'
alias grl3='git reflog -n 3'
alias grl5='git reflog -n 5'
alias grl10='git reflog -n 10'
alias grl25='git reflog -n 25'
# Tag aliases
alias gta='git tag -a'
alias gtl='git tag -l'
alias gtl1='git tag -l | head -n 1'
alias gtl2='git tag -l | head -n 2'
alias gtl5='git tag -l | head -n 5'
alias gtlg='git tag -l | grep'
alias gtlgi='git tag -l | grep -i'
alias gtll='git_tag_last'
alias gtll1='git_tag_last 1'
alias gtll2='git_tag_last 2'
alias gtll5='git_tag_last 5'
alias gtp='git_tag_prev'
alias gtd='git tag -d'
alias gtc='git_tag_create'
alias gtf='git tag --contains'
alias gtls='git log --tags --simplify-by-decoration --pretty="format:%ai %d"'
alias gtda='git tag -l | xargs git tag -d'
alias gtdl='git tag -l | xargs git tag -d; git fetch'
alias gtg='git tag'
# Add aliases
alias ga='git add'
alias gan='git add $(git ls-files -o --exclude-standard)'
alias gau='git add -u'
# Patch aliases
alias gpm='git diff -p'
alias gpf='git format-patch -1'
alias gpa='git apply'
# Subtree aliases
alias gsbta='git_subtree_add'
alias gsbtu='git_subtree_update'
# Git grep aliases
alias ggp='git grep'
alias ggg='git grep -n'
alias iggg='git grep -ni'
# Checkout aliases
alias gco='git checkout'
#alias gcot='git checkout --theirs'
#alias gcoo='git checkout --ours'
alias gcot='git_checkout_theirs'
alias gcoo='git_checkout_ours'
# Reset aliases
alias gre='git reset'
alias grh='git reset HEAD'
alias grh1='git reset HEAD~'
alias grh2='git reset HEAD~2'
alias grhh='git reset HEAD --hard'
alias grt='git reset $(git_tracking)'
grev() { git reset "$@"; git checkout -- "$@"; }
# Cherry-pick
alias gcp='git cherry-pick'
# Rebase aliases
alias grb='git_rebase'
alias grbi='git_rebase_interactive'
# Fetch/pull/push aliases
alias gpu='git push'
alias gpuu='git push -u'
alias gpua='git_push_all'
alias gpunc='git push -o ci.skip -o integrations.skip_ci'
alias gup='git_pull'
alias gupa='git_pull_all'
alias gfa='git fetch --all --tags'
# Config aliases
alias gcg='git config --get'
alias gcs='git config --set'
alias gcl='git config -l'
alias gcf='git config -l'
alias gcfg='git config -g'
# Git ignore changes
alias git_ignore_changes='git update-index --assume-unchanged'
alias git_noignore_changes='git update-index --no-assume-unchanged'
# gitk aliases
alias gk='gitk'
alias gkt='gitk HEAD $(git_tracking)'
alias gkh='gitk HEAD'
# ls aliases
alias gls='git_ls'
alias glsg='git_ls | grep'
alias glsc='git_ls_commit'
alias glscg='git_ls_commit | grep'
# BFG
alias bfg='java -jar "$RC_DIR/bin/profile/bfg.jar"'


########################################
########################################
# Last commands in file
# Execute function from command line
[ "${1#git}" != "$1" ] && "$@" || true

