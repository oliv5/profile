#!/bin/sh
# Interactive script to add a local user, generate a random password, setup SSH key
set -e -u # best effort to stop on error

question() { local ANSWER; read -p "$1" ANSWER; echo $ANSWER; }

# Create user
USER="${1:?No user name specified...}"
if ! id "$USER" >/dev/null 2>&1; then
    sudo groupadd -f "$USER"
    sudo useradd --gid "$USER" --create-home "$USER"
else
    echo "Skip creating existing user..."
fi
echo

# Set temp password
if [ "$(question 'Set temporary password (y/n)? ')" = "y" ]; then
    PASSWORD="$(stty -echo; question "Enter password (empty = random): "; stty echo)"
    if [ -z "$PASSWORD" ]; then
        PASSWORD="$(date +%s | sha256sum | base64 | head -c 16)"
        echo "Generated password: $PASSWORD"
    fi
    echo "Generated password: $PASSWORD"
    (echo $PASSWORD; echo $PASSWORD) | sudo passwd "$USER"
    sudo passwd --expire "$USER"
    sudo passwd --unlock "$USER"
else
    echo "Lock account password..."
    sudo passwd --lock "$USER"
fi
echo

# Set SSH authorized key
if [ "$(question 'Set SSH pubkey (y/n)? ')" = "y" ]; then
    sudo mkdir -p "/home/$USER/.ssh/"
    sudo vi "/home/$USER/.ssh/authorized_keys"
    sudo chown -R "$USER:$USER" "/home/$USER/.ssh"
    sudo chmod -R u+rwX,go-rwx "/home/$USER/.ssh"
fi
echo

# Select user shell
if [ "$(question 'Change user shell (y/n)? ')" = "y" ]; then
    echo "Available shells:"
    grep ^/bin /etc/shells
    echo -n "Your choice: "
    read CHOICE
    if [ -f "$CHOICE" ] && [ -x "$CHOICE" ]; then
        sudo usermod --shell "$CHOICE" "$USER"
    fi
fi

# Add to groups
for GRP in sudo admin lpadmin docker vboxusers wireshark dialout plugdev adm cdrom; do
    if grep "^$GRP:" /etc/group >/dev/null; then
        if [ "$(question 'Add user to the existing '"$GRP"' group (y/n)? ')" = "y" ]; then
            sudo usermod -a -G "$GRP" "$USER"
        fi
    else
        if [ "$(question 'Create group '"$GRP"' and add user into (y/n)? ')" = "y" ]; then
            sudo groupadd -f "$GRP"
            sudo usermod -a -G "$GRP" "$USER"
        fi
    fi
done
echo

# Setup sudo
for CMD in "/sbin/ip netns exec"; do
    if [ "$(question 'Allow user to run "'"$CMD"'" with sudo without password (y/n)? ')" = "y" ]; then
        cat <<-EOF | sudo EDITOR="tee -a" visudo -f "/etc/sudoers.d/75_$USER"
$USER ALL=NOPASSWD: $CMD
EOF
    fi
done
echo
