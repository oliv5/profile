#!/bin/sh

# Cleanup
flatpak_cleanup() {
  flatpak uninstall --unused
}
