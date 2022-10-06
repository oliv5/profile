#!/bin/sh

# Basic implementation of cd/back/forward functions
cda() { :; } # for compatibility
cdb() { command cd -; }
cdf() { command cd -; }

# Clean up all custom mappings
cdu() { unalias cd cda cdb cdf 2>/dev/null || true; unset -f cd cda cdb cdf 2>/dev/null; }

# Mkdir and cd
mkcd () { mkdir -p "$@" && cd "$@"; }

# Quick cd
gcd() { cd *"$1"*"$2"*"$3"*"$4"*"$5"*"$6"*"$7"*"$8"*"$9"*; }
