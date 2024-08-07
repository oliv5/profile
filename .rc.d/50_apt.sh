#!/bin/sh

# Package management (apt/dpkg)
alias dpkg_archi='dpkg --print-architecture'
alias dpkg_download='apt-get download'
alias dpkg_installed='dpkg -s'
alias dpkg_content='dpkg -L'
alias dpkg_search='dpkg -S'
alias dpkg_ls='dpkg -l'
alias dpkg_ls_conf='dpkg -l | grep -E ^rc'
alias dpkg_clean='sudo apt-get autoclean; sudo apt-get clean; sudo apt-get autoremove'
alias dpkg_clean_conf='dpkg -l | awk "\$1 ~ /rc/ {print \$2}" | xargs -r sudo apt-get purge'
alias dpkg_rm_forced='sudo pkg --remove --force-remove-reinstreq'
alias dpkg_rm_ppa='sudo add-apt-repository --remove'
alias dpkg_search_old='apt-show-versions | grep "No available version"'
alias dpkg_search_old2='aptitude search "~o"'
alias dpkg_search_orphan='aptitude search "~c"'
alias dpkg_lock='dpkg_lock'
alias dpkg_unlock='dpkg_unlock'
alias dpkg_locked='dpkg_locked'

# Lock/unlock packages
# https://askubuntu.com/questions/18654/how-to-prevent-updating-of-a-specific-package
dpkg_status() {
  # status: install/hold/deinstall/purge
  eval dpkg --get-selections ${1:+| grep "$1"}
}
dpkg_locked() {
  dpkg --get-selections | awk '$2 == "hold" {print}'
}
dpkg_lock() {
  echo "${1:?No package specified...} hold" | sudo dpkg --set-selections
}
dpkg_unlock() {
  echo "${1:?No package specified...} install" | sudo dpkg --set-selections
}
alias apt_lock='sudo apt-mark hold'
alias apt_unlock='sudo apt-mark unhold'
alias apt_locked='sudo apt-mark showhold'
alias aptitude_lock='sudo aptitude hold'
alias aptitude_unlock='sudo aptitude unhold'

# Kernel management
alias kernel_ls="dpkg -l 'linux-*'"
alias kernel_current='uname -r | sed "s/\(.*\)-\([^0-9]\+\)/\1/"'
alias kernel_others="dpkg -l 'linux-*' | sed '/^ii/!d;/'$(uname -r | sed "s/\(.*\)-\([^0-9]\+\)/\1/")'/d;s/^[^ ]* [^ ]* \([^ ]*\).*/\1/;/[0-9]/!d'"

# DKMS modules
alias dkms_rebuild='sudo sh -c "ls /lib/modules | sudo xargs -n1 /usr/lib/dkms/dkms_autoinstaller start"'
alias dkms_broken='for i in /var/lib/dkms/*/[^k]*/source; do [ -e "$i" ] || echo "$i";done'
alias dkms_ls='dkms status'
dkms_rm_force() { sudo dkms remove --all "${@:?No module specified, like <module/version>...}"; }

# Make deb package from source
deb_make() {
  local ARCHIVE="${1:?No input archive specified}"
  tar zxf "$ARCHIVE" "${ARCHIVE%.*}" || return 0
  cd "${ARCHIVE%.*}"
  ./configure || return 0
  dh_make -s -f "../$ARCHIVE"
  fakeroot debian/rules binary
}

# Script to list all the PPA installed on a system
# https://askubuntu.com/questions/148932/how-can-i-get-a-list-of-all-repositories-and-ppas-from-the-command-line-into-an
pkg_ls_ppa() {
  for APT in `find /etc/apt/ -name \*.list`; do
      grep -Po "(?<=^deb\s).*?(?=#|$)" $APT | while read ENTRY ; do
          HOST=`echo $ENTRY | cut -d/ -f3`
          USER=`echo $ENTRY | cut -d/ -f4`
          PPA=`echo $ENTRY | cut -d/ -f5`
          #echo sudo apt-add-repository ppa:$USER/$PPA
          if [ "ppa.launchpad.net" = "$HOST" ]; then
              echo ppa:$USER/$PPA
          else
              echo \'${ENTRY}\'
          fi
      done
  done
}

# Permanent --no-install-recommends
apt_no_recommends() {
  if [ "$1" = "disable" ]; then
    sudo rm -v /etc/apt/apt.conf.d/01norecommend
  else
    sudo tee /etc/apt/apt.conf.d/01norecommend << EOF
APT::Install-Recommends "0";
APT::Install-Suggests "0";
EOF
    ls /etc/apt/apt.conf.d/01norecommend
  fi
}

# List apt sources
apt_show_src() {
  find /etc/apt -type f \( -name '*.list*' -o -name '*.sources' \) -exec sh -c 'echo "\n\t$1\n"; [ "${1##*.}" = "list" -o "${1##*.}" = "sources" ] && cat -n "$1"' _ '{}' \;
}
