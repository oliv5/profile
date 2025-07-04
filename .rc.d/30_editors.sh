#!/bin/sh

#########################
# Default editors
[ -z "$EDITOR" ] && export EDITOR="$(command -v vi -e || command -v false)"
[ -z "$VISUAL" ] && export VISUAL="$(command -v vim || command -v vi || command -v nano || command -v false)"
[ -z "$PAGER" ] && export PAGER="less -FXr"
export LESS="-FXr" # Don't stop when less than 1 page, color

#########################
# Gedit
if command -v gedit >/dev/null; then
  gedit() {
    local ARG ARGS=""
    for ARG; do
      ARGS="${ARGS:+$ARGS }$(echo "$ARG" | awk -F':' '{printf "+%s \"%s\"",$2,$1}')"
    done
    eval command gedit "$ARGS"
  }
fi

#########################
# Geany
if command -v geany >/dev/null; then
  geany() {
    local ARG ARGS=""
    for ARG; do
      ARGS="${ARGS:+$ARGS }$(echo "$ARG" | awk -F':' '{printf "+%s \"%s\"",$2,$1}')"
    done
    eval command geany "$ARGS"
  }
fi

#########################
# Vim
export COLORTERM="xterm" # backspace bug in vim
export VI="$(command -v vim || command -v vi)"
unset VIM # bug at startup if defined
unset VIM_USETABS
unset VIM_NOREMOTE

# Manage gvim command line options
if command -v gvim >/dev/null; then
  export VI="gvim"
  gvim() {
    local ARGS="$1"
    if [ -n "$ARGS" -a "$ARGS" != "-" ]; then
      ARGS="$(echo "$ARGS" | awk -F':' '{printf "+%s \"%s\"",$2,$1}')"
      if [ -z "$VIM_NOREMOTE" ]; then
        ARGS="${ARGS:+--remote-${VIM_USETABS:+tab-}silent }$ARGS"
      fi
    fi
    shift
    local ARG
    for ARG; do
      if [ "$ARG" != "-" ]; then
        ARG="$(echo "$ARG" | awk -F':' '{printf "\"%s\"",$1}')"
      fi
      ARGS="${ARGS:+$ARGS }$ARG"
    done
    eval command gvim $ARGS
    echo gvim $ARGS
  }
fi

# Manage nvim-qt command line options
# Need: pip3 install neovim-remote
if command -v nvim-qt >/dev/null; then
  alias gnvim="nvimqt"
  export VI="nvimqt"
  nvimqt() {
    local ARG
    local ARGS=""
    for ARG; do
      # nvim argument "+line" can be set anywhere and is applied to the first file only
      ARG="$(echo "$ARG" | awk -F':' '{ if (length($1)>0) printf "\"%s\"",$1; if (length($2)>0) {printf " +%s",$2} }')"
      ARGS="${ARGS:+$ARGS }$ARG"
    done
    [ -z "$ARGS" ] && return
    if pgrep nvim >/dev/null; then
      eval command nvr --remote $ARGS
      command -v wmctrl >/dev/null && wmctrl -R Neovim
    else
      rm /tmp/nvimsocket 2>/dev/null || true
      eval command nvim-qt -- --listen /tmp/nvimsocket $ARGS
    fi
    echo nvim-qt $ARGS
  }
fi

#########################
# Source insight using desktop file
sourceinsight3() {
  if command -v gtk-launch >/dev/null; then 
    for P in "si3${1:+-$1}" "sourceinsight3${1:+-$1}"; do
      gtk-launch "$P" 2>/dev/null
    done
  fi
}

# Source insight using desktop file
sourceinsight4() {
  if command -v gtk-launch >/dev/null; then 
    for P in "si4${1:+-$1}" "sourceinsight4${1:+-$1}"; do
      gtk-launch "$P" 2>/dev/null
    done
  fi
}

#########################
# File manager
if [ -z "$FMANAGER" ];then
  export FMANAGER="$(command -v nautilus || command -v konqueror || command -v dolphin || command -v gnome-commander)"
fi

#########################
# Graphical editors
export GEDITOR="$(command -v geany || command -v gvim || command -v gedit || command -v false)"
