# ~/.profile: executed by the command interpreter for login shells.
# Not read by bash(1), if ~/.bash_profile or ~/.bash_login exists.

# the default umask is set in /etc/profile; for setting the umask
# for ssh logins, install and configure the libpam-umask package.
umask 022

# Execute system wide profile
#if [ -f /etc/profile ]; then
#  . /etc/profile
#fi

# Find local dir
LOCAL_DIR="$(test -n "$BASH_VERSION" && dirname "${BASH_SOURCE[0]}" || dirname "$0")"

# Set global variables
export ENV_PROFILE=$((ENV_PROFILE+1))

# Declare user script (posix shells only)
if [ -z "$ENV" ]; then
  if [ -r ~/.dashrc ]; then
    export ENV=~/.dashrc
  elif [ -r "$LOCAL_DIR"/.dashrc ]; then
    export ENV="$LOCAL_DIR"/.dashrc
  fi
fi

# Exports
export PATH

# make sure this is the last line
# to ensure a good return code
