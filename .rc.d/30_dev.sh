#!/bin/sh

# Find file in a CVS, fallback to std file search otherwise
alias dff='_dfind'
_dfind() { local DIR="$(dirname "$1")"; if git_exists "$DIR"; then git ls-files "*$@"; elif svn_exists "$DIR"; then svn ls -R "$DIR" | grep -E "$@"; else _ffind "$@"; fi; }

# Find a CVS root folder
alias rff='_rfind'
_rfind() { if svn_exists "$@"; then svn_root "$@"; elif git_exists "$@"; then git_worktree "$@"; fi };

# Find file & open
_ffv() {
  local FF="${1:?No find fct specified...}"
  local ED="${2:?No editor specified...}"
  local FCT_ED="$(fct_def "$ED")"
  shift 2
  for F; do
    local FILE="${F%%:*}"
    local LINE="${F#*:}"; LINE="${LINE%%:*}"; [ "$LINE" = "$F" ] && LINE=""
    eval "$FF" "$FILE" | sort -z | xargs -r0 sh -c "$FCT_ED; $ED \$@:$LINE" _
  done
}
ffv()   { _ffv ff0 "${VI:-gvim}" "$@"; }
iffv()  { _ffv iff0 "${VI:-gvim}" "$@"; }
ffv1()  { _ffv ff1 "${VI:-gvim}" "$@"; }
iffv1() { _ffv iff1 "${VI:-gvim}" "$@"; }

# Grep based code search
_dgrep1()   { local A="$2" B="$1" C="$3"; shift $(($#<3?$#:3)); (set -f; FARGS="${_DG1EXCLUDE} $@" _fgrep1 "$A" "${C:-.}/$B"); }
_dgrep2()   { local A="$2" B="$1" C="$3"; shift $(($#<3?$#:3)); (set -f; _fgrep2 "$A" ${_DG2EXCLUDE} "$@" "${C:-.}/$B"); }
_dgrep3()   { local A="$2" B="$1" C="$3"; shift $(($#<3?$#:3)); (set -f; git grep -nE ${GCASE} ${GARGS} "$@" "$A" -- $(_fglob "$B" "${C:-.}/*" " ")); }
_dgrep4()   { local A="$2" B="$1" C="$3"; shift $(($#<3?$#:3)); (set -f; _rgrep "$A" "${C:-.}/($B)" ${GCASE} "$@"); }
_dgrep()    { if command -v _rgrep >/dev/null; then _dgrep4 "$@"; elif git_exists "$3"; then _dgrep3 "$@"; else _dgrep1 "$@"; fi; }
_DG1EXCLUDE=""
_DG2EXCLUDE="--exclude-dir=.git --exclude-dir=.svn"
_DGEXT_C="*.c|*.cpp|*.cc"
_DGEXT_H="*.h|*.hpp"
_DGEXT_V="*.vhd|*.v|*.sv"
_DGEXT_PY="*.py"
_DGEXT_SCONS="SConstruct|SConscript|sconstruct|sconscript"
_DGEXT_CMAKE="CMakeLists.txt|cmakelists.txt|*.cmake"
_DGEXT_MAKE="*.mk|Makefile|makefile|GNUmakefile|gnumakefile|*.make"
_DGEXT_MK="$_DGEXT_MAKE|$_DGEXT_CMAKE|$_DGEXT_SCONS"
_DGEXT_ASM="*.inc|*.S|*.s|*.asm|*.ASM"
_DGEXT_XML="*.xml"
_DGEXT_TEX="*.tex"
_DGEXT_SHELL="*.sh"
_DGEXT_REF="$_DGEXT_C|$_DGEXT_H|$_DGEXT_V|$_DGEXT_PY|$_DGEXT_SCONS|$_DGEXT_MK|$_DGEXT_ASM|$_DGEXT_XML|$_DGEXT_SHELL"
alias     _c='FCASE= FTYPE=  FXTYPE= FARGS= GCASE=   GARGS= _dgrep "$_DGEXT_C"'
alias     _h='FCASE= FTYPE=  FXTYPE= FARGS= GCASE=   GARGS= _dgrep "$_DGEXT_H"'
alias     _v='FCASE= FTYPE=  FXTYPE= FARGS= GCASE=   GARGS= _dgrep "$_DGEXT_V"'
alias     ch='FCASE= FTYPE=  FXTYPE= FARGS= GCASE=   GARGS= _dgrep "$_DGEXT_C|$_DGEXT_H"'
alias     py='FCASE= FTYPE=  FXTYPE= FARGS= GCASE=   GARGS= _dgrep "$_DGEXT_PY"'
alias     mk='FCASE= FTYPE=  FXTYPE= FARGS= GCASE=   GARGS= _dgrep "$_DGEXT_MK"'
alias    asm='FCASE= FTYPE=  FXTYPE= FARGS= GCASE=   GARGS= _dgrep "$_DGEXT_ASM"'
alias    xml='FCASE= FTYPE=  FXTYPE= FARGS= GCASE=   GARGS= _dgrep "$_DGEXT_XML"'
alias    tex='FCASE= FTYPE=  FXTYPE= FARGS= GCASE=   GARGS= _dgrep "$_DGEXT_TEX"'
alias  shell='FCASE= FTYPE=  FXTYPE= FARGS= GCASE=   GARGS= _dgrep "$_DGEXT_SHELL"'
alias    ref='FCASE= FTYPE=  FXTYPE= FARGS= GCASE=   GARGS= _dgrep "$_DGEXT_REF"'
alias     ic='FCASE= FTYPE=  FXTYPE= FARGS= GCASE=-i GARGS= _dgrep "$_DGEXT_C"'
alias     ih='FCASE= FTYPE=  FXTYPE= FARGS= GCASE=-i GARGS= _dgrep "$_DGEXT_H"'
alias     iv='FCASE= FTYPE=  FXTYPE= FARGS= GCASE=-i GARGS= _dgrep "$_DGEXT_V"'
alias    ich='FCASE= FTYPE=  FXTYPE= FARGS= GCASE=-i GARGS= _dgrep "$_DGEXT_C|$_DGEXT_H"'
alias    ipy='FCASE= FTYPE=  FXTYPE= FARGS= GCASE=-i GARGS= _dgrep "$_DGEXT_PY"'
alias    imk='FCASE= FTYPE=  FXTYPE= FARGS= GCASE=-i GARGS= _dgrep "$_DGEXT_MK"'
alias   iasm='FCASE= FTYPE=  FXTYPE= FARGS= GCASE=-i GARGS= _dgrep "$_DGEXT_ASM"'
alias   ixml='FCASE= FTYPE=  FXTYPE= FARGS= GCASE=-i GARGS= _dgrep "$_DGEXT_XML"'
alias   itex='FCASE= FTYPE=  FXTYPE= FARGS= GCASE=-i GARGS= _dgrep "$_DGEXT_TEX"'
alias ishell='FCASE= FTYPE=  FXTYPE= FARGS= GCASE=-i GARGS= _dgrep "$_DGEXT_SHELL"'
alias   iref='FCASE= FTYPE=  FXTYPE= FARGS= GCASE=-i GARGS= _dgrep "$_DGEXT_REF"'

# Grep based code block search
_dsearch1() { local A="$1"; local B="$2"; shift $(min 2 $#); (set -f; GARGS=-E _dgrep1 $_DGEXT_REF "${A//NAME/$B}" "$@"); } # Single line
_dsearch2() { local A="$1"; local B="$2"; shift $(min 2 $#); (set -f; GARGS="-Ezo --color=always" _dgrep1 $_DGEXT_REF "${A//NAME/$B}" "$@" | xargs -r0 -n1; echo); } # Multiline
_dsearch3() { local A="$1"; local B="$2"; shift $(min 2 $#); (set -f; _rgrep "${A//NAME/$B}" $_DGEXT_REF -U ${GCASE}); }
_dsearch() { if command -v _rgrep >/dev/null; then _dsearch3 "$@"; else _dsearch2 "$@"; fi; }
#_DGREGEX_FUNC='\S*\s*NAME\s*\(\s*($|\S+\s+\S+|void)' # Single line
_DGREGEX_FUNC='NAME\s*\([^\n;]*\)\s*\{' # Multiline
# _DGREGEX_VAR='^[^\(]*\S+\s*(\*|&)*\s*NAME\s*(=.+|\(\S+\)|\[.+\])?\s*(;|,)' # Single line
_DGREGEX_VAR='[\w\*]+\s*NAME[\s\n]*(=[^;=]+)?;' # Multiline
_DGREGEX_STRUCT='(struct|union|enum|class)\s*NAME\s*(\{|$)'
_DGREGEX_TYPEDEF='(typedef\s+\w+\s+NAME)|(^\s*NAME\s*;)'
_DGREGEX_DEFINE='(#define\s+NAME)|(^\s*NAME\s*,)|(^\s*NAME\s*=.*,)'
_DGREGEX_ALL="($_DGREGEX_FUNC)|($_DGREGEX_VAR)|($_DGREGEX_STRUCT)|($_DGREGEX_TYPEDEF)|($_DGREGEX_DEFINE)"
alias      def='FCASE= FTYPE=  FXTYPE= FARGS= GCASE=   GARGS= _dsearch "$_DGREGEX_ALL"'
alias      var='FCASE= FTYPE=  FXTYPE= FARGS= GCASE=   GARGS= _dsearch "$_DGREGEX_VAR"'
alias     func='FCASE= FTYPE=  FXTYPE= FARGS= GCASE=   GARGS= _dsearch "$_DGREGEX_FUNC"'
alias   struct='FCASE= FTYPE=  FXTYPE= FARGS= GCASE=   GARGS= _dsearch "$_DGREGEX_STRUCT"'
alias   define='FCASE= FTYPE=  FXTYPE= FARGS= GCASE=   GARGS= _dsearch "$_DGREGEX_DEFINE"'
alias  typedef='FCASE= FTYPE=  FXTYPE= FARGS= GCASE=   GARGS= _dsearch "$_DGREGEX_TYPEDEF"'
alias     idef='FCASE= FTYPE=  FXTYPE= FARGS= GCASE=-i GARGS= _dsearch "$_DGREGEX_ALL"'
alias     ivar='FCASE= FTYPE=  FXTYPE= FARGS= GCASE=-i GARGS= _dsearch "$_DGREGEX_VAR"'
alias    ifunc='FCASE= FTYPE=  FXTYPE= FARGS= GCASE=-i GARGS= _dsearch "$_DGREGEX_FUNC"'
alias  istruct='FCASE= FTYPE=  FXTYPE= FARGS= GCASE=-i GARGS= _dsearch "$_DGREGEX_STRUCT"'
alias  idefine='FCASE= FTYPE=  FXTYPE= FARGS= GCASE=-i GARGS= _dsearch "$_DGREGEX_DEFINE"'
alias itypedef='FCASE= FTYPE=  FXTYPE= FARGS= GCASE=-i GARGS= _dsearch "$_DGREGEX_TYPEDEF"'

# Dev replace
#_DSEXCLUDE="-not -path */.svn* -and -not -path */.git* -and -not -type l"
_DSEXCLUDE="-not -path '*/.*' -and -not -type l"
alias  dhh='FCASE=   FTYPE= FXTYPE= FARGS= SFILES="$_DGEXT_REF" SEXCLUDE="$_DSEXCLUDE" _fsed2'
alias idhh='FCASE=-i FTYPE= FXTYPE= FARGS= SFILES="$_DGEXT_REF" SEXCLUDE="$_DSEXCLUDE" _fsed2'

# Parallel make (needs ipcmd tool)
# https://code.google.com/p/ipcmd/wiki/ParallelMake
pmake() {
	# Call make protected by semaphores when ipcmd is available
	# Otherwise call make directly
	if command -v ipcmd >/dev/null; then
		local IPCMD_SEMID="$(ipcmd semget)"
		local AR="ipcmd semop -s $IPCMD_SEMID -u -1 : ar"
		local RANLIB="ipcmd semop -s $IPCMD_SEMID -u -1 : ranlib"
		local PYTHON="ipcmd semop -s $IPCMD_SEMID -u -1 : python"
		local TRAP="ipcrm -s '$IPCMD_SEMID'; trap INT"
		ipcmd semctl -s "$IPCMD_SEMID" setall 1
		trap "ipcrm -s '$TRAP'" INT
		command make AR="$AR" RANLIB="$RANLIB" PYTHON="$PYTHON" "$@"
		local RETCODE=$?
		eval "$TRAP"
		return $RETCODE
	else
		make "$@"
	fi
}

# Tab vs spaces
space2tab() {
	local FILES="${1:?No files defined...}"
	local TABSIZE="${2:-4}"
	local TABNUM="${3:-10}"
	_ffind "$FILES" -type f -print0 | xargs -r0 -- sh -c '
		TABSIZE="$1"
		TABNUM="$2"
		shift 2
		for FILE; do
			for N in $(seq "$TABNUM" -1 1); do
				sed -r -i -e "s/^(\t*)( {$TABSIZE})/\1\t/" "$FILE"
			done
		done
	' _ "$TABSIZE" "$TABNUM"
}
tab2space() {
	local FILES="${1:?No files defined...}"
	local TABSIZE="${2:-4}"
	local TABNUM="${3:-10}"
	local SPACES=""
	for N in $(seq $TABSIZE); do SPACES="${SPACES} "; done
	_ffind "$FILES" -type f -print0 | xargs -r0 -- sh -c '
		TABSIZE="$1"
		TABNUM="$2"
		SPACES="$3"
		shift 3
		for FILE; do
			for N in $(seq "$TABNUM" -1 1); do
				sed -r -i -e "s/^( *)\t/\1$SPACES/" "$FILE"
			done
		done
	' _ "$TABSIZE" "$TABNUM" "$SPACES"
}

# Uncrustify
uncrust() {
	command -v uncrustify >/dev/null 2>&1 && echo "ERROR: cannot find uncrustify..." && return 1
	local CFG="${XDG_CONFIG_HOME:-$HOME/.config}/uncrustify/${2:-$(uncrustify --version)}.cfg"
	find "${1:?No source folder specified...}" -type f -regex '.*\.\(c\|h\|cpp\|cc\|hpp\)' -print0 | xargs -r0 -n1 -- uncrustify -c "$CFG" --no-backup -f
}

# Gcc/clang show definitions
gcc_show_def() {
	gcc "$@" -dM -E - < /dev/null
}
gpp_show_def() {
	g++ "$@" -dM -E - < /dev/null
}
clang_show_def() {
	clang "$@" -dM -E - < /dev/null
}
