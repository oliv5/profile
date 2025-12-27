#!/bin/sh

# Cleanup
flatpak_cleanup() {
  flatpak uninstall --unused
}

# List packages
alias flatpakg='flatpak list | grep -i'
