#!/bin/sh
# Run with cmd: (curl https://raw.githubusercontent.com/oliv5/profile/master/bin/profile/bootstrap-profile.sh -L | sh)
set -e

###################
ask_question() { 
    local REPLY
    local ACK
    local STDIN=/dev/fd/0
    if [ -c "/dev/fd/$1" ]; then
        STDIN=/dev/fd/$1
        shift $(($# > 1 ? 1 : $#))
    fi
    read ${1:+-p "$1"} REPLY < ${STDIN}
    shift $(($# > 1 ? 1 : $#))
    echo "$REPLY"
    for ACK in "$@"; do
        [ "$REPLY" = "$ACK" ] && return 0
    done
    return 1
}

###################
# Install a set of packages
install_packages() {
	if apt --version >/dev/null 2>&1; then
		sudo apt install "$@"
	elif pkg --version >/dev/null 2>&1; then
		pkg install "$@"
	else
		echo >&2 "Warning: no installer for package(s) $*"
		return 1
	fi
}

# Install from sources
install_from_sources() {
	local PACKAGE="${1:?No package specified...}"
	local URL="${2:?No URL specified...}"
	local DST="$HOME/.local/bin"
	shift $(($# > 2 ? 2 : $#))

	# Download sources
	mkdir -p "$DST"
	DST="$DST/_$PACKAGE"
	if [ "${URL%.git}" != "$URL" ]; then
		git clone --depth 1 "$URL" "$DST" ||
			return 2
	elif [ "${URL%.tgz}" != "$URL" ] || [ "${URL%.tar.gz}" != "$URL" ]; then
		mkdir -p "$DST"
		curl "$URL" | tar -xvz -C "$DST" ||
			return 2
	else
		wget "$URL" -O "$DST" &&
			chmod a+x "$DST" ||
			return 2
	fi

	# Post-install
	if [ $# -gt 0 ]; then
		( cd "$DST"; for CMD; do eval "$CMD"; done )
	fi

	return 0
}

# Install program
install() {
	local CMD="${1:?No command specified...}"
	local PACKAGE="${2:?No package specified...}"
	local URL="$3"
	local DST="$HOME/.local/bin"

	if command -v "$CMD" >/dev/null; then
		echo >&2 "Warning: skip already-installed package $PACKAGE ..."
		echo
		return 0
	fi

	echo "Install package $PACKAGE ..."

	if ! install_packages "$PACKAGE"; then
		if [ -n "$URL" ]; then
			shift 1
			install_from_sources "$@"
		else
			echo >&2 "Warning: no clone url specified, skip package $PACKAGE ..."
			echo
			return 1
		fi
	fi
	
	echo "Done!"
	echo

	return 0
}

###################
bootstrap_profile() {
	# Check prerequisites
	if ! export HOME 2>/dev/null; then
		echo >&2 "Error: you are not using a bash/dash compatible shell ($SHELL); Abort..."
		return 1
	fi

	# Choose where to put the HOME folder
	local NEW_HOME
	local OLD_HOME="$HOME"
	read -p "Change HOME path ($HOME)? (empty = no change): " NEW_HOME
	HOME="${NEW_HOME:-$HOME}"
	if [ "$HOME" != "$OLD_HOME" ]; then
		echo "HOME: $HOME"
		read -p "Continue? (enter/ctrl-c)" NEW_HOME
		mkdir -p "$HOME"
		export HOME
	fi

	# Setup packages
	install sshd openssh-server
	install ssh openssh-client
	install git git
	install wget wget
	install rsync rsync
	install curl curl
	install gpg gnupg
	install gawk gawk
	install make make
	if [ "$(uname -p)" = "x86_64" ]; then
		install git-annex git-annex https://downloads.kitenet.net/git-annex/linux/current/git-annex-standalone-amd64.tar.gz
	elif [ "$(uname -m)" = "aarch64" ]; then
		install git-annex git-annex https://downloads.kitenet.net/git-annex/linux/current/git-annex-standalone-armel.tar.gz
	else
		echo >&2 "Warning: unknown target; skip installing git-annex ..."
	fi
	install mr myrepos https://github.com/joeyh/myrepos.git "ln -s _mr/mr ../"
	install vcsh vcsh https://github.com/RichiH/vcsh.git "ln -s _vcsh/vcsh ../"
	install repo repo https://storage.googleapis.com/git-repo-downloads/repo
	install fdfind fd-find https://github.com/sharkdp/fd.git "install cargo cargo" "make"
	install rpl rpl https://github.com/kcoyner/rpl.git "ln -s _rpl/rpl ../"
	install fzf fzf https://github.com/junegunn/fzf.git "./install --no-fish --no-zsh"

	# Clone profile repository
	local URL="https://github.com/oliv5/profile.git"
	if [ "$HOME" = "$OLD_HOME" ]; then
		if ! vcsh list | grep profile >/dev/null; then
			vcsh clone "$URL" profile
		else
			echo >&2 "Warning: skip cloning existing profile repo ..."
		fi
	else
		if ! [ -d "$PRIVATE/profile" ]; then
			git clone "$URL" "$PRIVATE/profile"
		else
			echo >&2 "Warning: skip cloning existing profile repo ..."
		fi
	fi
}

###################
bootstrap_profile "$@"
