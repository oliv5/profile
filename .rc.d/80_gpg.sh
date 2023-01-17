#!/bin/sh

# Test GPG encryption key
gpg_test_key() {
	local WHO="${1:?No recipient specified...}"
	echo "1234" | gpg --no-use-agent -o /dev/null --local-user "$WHO" -as - && echo "The correct passphrase was entered for this key"
}

# Exports
alias gpg_export_pub='gpg --armor --export'
alias gpg_export_priv='gpg --armor --export-secret-key'
gpg_export_all() {
	local WHO="${1:?No recipient specified...}"
	local NAME="${2:?No output file name specified...}"
	gpg --armor --export "$WHO" > "${NAME}.pub.asc"
	gpg --armor --export-secret-keys "$WHO" > "${NAME}.sec.asc"
	gpg --armor --export-secret-subkeys "$WHO" > "${NAME}.sec.sub.asc"
	gpg --armor --gen-revoke "$WHO" > "${NAME}.rev.asc"
}

# Shortcut for gpg-preset-passphrase not in the path
gpg-preset-passphrase() {
	command "$(gpgconf --list-dirs libexecdir)"/gpg-preset-passphrase "$@"
}

# Ask one passphrase and register it in the agent
# allow-preset-passphrase must be in ~/.gnupg/gpg-agent.conf
# https://superuser.com/questions/1539189/gpg-preset-passphrase-caching-passphrase-failed-not-supported
gpg_agent_load_passphrase() {
	if ! grep allow-preset-passphrase "$HOME/.gnupg/gpg-agent.conf" >/dev/null; then
		echo >&2 "Error: allow-preset-passphrase is not in ~/.gnupg/gpg-agent.conf ..."
		return 1
	fi
	
	# Ask passphrase
	local PASSPHRASE
	trap 'stty echo' INT
	stty -echo
	read -p "Passphrase: " PASSPHRASE
	stty echo
	trap - INT
	echo

	# Start agent and get key IDs
	# Output looks like
	#S KEYINFO B1A955E910AEFAAB2FAD9EADBFAA5C59AFAAF0AA D - - - P - - -
	#S KEYINFO AAA2AAE20FCB9621D22BAFEE1C0AA2B011AA6AA6 D - - - P - - -
	#OK
	local KEYGRIP=
	
	# Loop over all keys and register the passphrase
	local KEY
	for KEY in $(gpg-connect-agent -q 'keyinfo --list' /bye | awk '/KEYINFO/ { print $3 }'); do
		echo "$PASSPHRASE" | /usr/lib/gnupg/gpg-preset-passphrase --preset "$KEY"
	done
}
