#!/bin/sh
# Run with cmd: (curl https://raw.githubusercontent.com/oliv5/profile/master/bin/profile/bootstrap-profile.sh -L | sh)
set -e

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
Main() {
	# Check prerequisites
	if ! export HOME 2>/dev/null; then
		echo >&2 "Error: you are not using a bash/dash compatible shell ($SHELL); Abort..."
		return 1
	fi

	# Choose if we use a private data folder
	PRIVATE="$1"
	if [ -z "$PRIVATE" ]; then
		read -p "Path to the private data directory, if any (empty is '\$HOME'): " PRIVATE
		PRIVATE="${PRIVATE:-$HOME}"
	fi
	if [ "$PRIVATE" != "$HOME" ]; then
		HOME="${PRIVATE}/home"
	fi

	echo "HOME: $HOME"
	echo "PRIVATE: $PRIVATE"
	read -p "Continue? (enter/ctrl-c)" ANSWER
	echo
	mkdir -p "$HOME"
	mkdir -p "$PRIVATE"
	export HOME
	export PRIVATE

	# Setup packages
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
	install mr mr https://github.com/joeyh/myrepos.git
	install vcsh vcsh https://github.com/RichiH/vcsh.git
	install repo repo https://storage.googleapis.com/git-repo-downloads/repo
	install fdfind fd-find https://github.com/sharkdp/fd.git "install cargo cargo" "make"
	install rpl rpl https://github.com/kcoyner/rpl.git "ln -s _rpl/rpl ../"
	install fzf fzf https://github.com/junegunn/fzf.git "./install --no-fish --no-zsh"

	# Clone profile repository
	URL="https://github.com/oliv5/profile.git"
	if [ "$PRIVATE" = "$HOME" ]; then
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
(Main "$@")
