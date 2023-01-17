#!/bin/sh
# Run with cmd: (curl https://raw.githubusercontent.com/oliv5/profile/master/bin/profile/bootstrap-profile.sh -L | sh)
set -e

###################
# Install a set of packages
install_package() {
	if apt --version >/dev/null 2>&1; then
		sudo apt install "$@"
	elif pkg --version >/dev/null 2>&1; then
		pkg install "$@"
	else
		echo >&2 "Warning: no installer for package(s) $*"
		return 1
	fi
}

# Install program
install() {
	local CMD="${1:?No command specified...}"
	local PACKAGE="${2:?No package specified...}"
	local URL="$3"
	local DST="${4:-$HOME/.local/bin}"
	if command -v "$CMD" >/dev/null; then
		echo >&2 "Warning: skip already-installed package $PACKAGE ..."
		return 0
	fi
	if ! install_package "$PACKAGE"; then
		if [ -n "$URL" ]; then
			mkdir -p "$DST"
			DST="$DST/$PACKAGE"
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
			export PATH="$PATH:$DST"
		else
			echo >&2 "Warning: no clone url specified, skip package $PACKAGE ..."
			return 1
		fi
	fi
	return 0
}

###################
Main() {
	# Check prerequisites
	if ! export HOME 2>/dev/null; then
		echo >&2 "Error: you are not using a bash/dash compatible shell ($SHELL); Abort..."
		return 1
	fi

	# Setup private data folder
	read -p "Choose the private data directory (empty is '\$HOME'): " PRIVATE
	PRIVATE="${PRIVATE:-$HOME}"
	if [ "$PRIVATE" != "$HOME" ]; then
		export HOME="${PRIVATE}/home"
	fi
	echo "HOME: $HOME"
	echo "PRIVATE: $PRIVATE"
	read -p "Continue? (enter/ctrl-c)" ANSWER
	mkdir -p "$HOME"
	mkdir -p "$PRIVATE"

	# Setup packages
	install git git
	install wget wget
	install rsync rsync
	install curl curl
	install gpg gnupg
	install gawk gawk
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
	install fdfind fdfind https://github.com/sharkdp/fd
	install rpl rpl https://github.com/kcoyner/rpl
	install fzf fzf https://github.com/junegunn/fzf

	# Clone profile repository
	URL="https://github.com/oliv5/profile.git"
	if [ "$PRIVATE" = "$HOME" ]; then
		if ! vcsh list | grep profile >/dev/null; then
			vcsh clone "$URL" profile
			export PATH="$PRIVATE/profile/bin:$PATH"
		else
			echo >&2 "Warning: skip cloning existing profile repo ..."
		fi
	else
		if ! [ -d "$PRIVATE/profile" ]; then
			cd "$PRIVATE"
			git clone "$URL" "$PRIVATE/profile"
			export PATH="$PRIVATE/profile/bin:$PATH"
		else
			echo >&2 "Warning: skip cloning existing profile repo ..."
		fi
	fi
}

###################
Main "$@"
