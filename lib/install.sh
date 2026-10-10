#!/usr/bin/env bash
# Shared Linux installer helpers. Source from the repository, not from $HOME.

rc_install_packages() {
  local -a privilege=()
  [[ $EUID -eq 0 ]] || privilege=(sudo)

  if command -v pacman >/dev/null 2>&1; then
    # Use the current database; refreshing it alone causes partial upgrades.
    "${privilege[@]}" pacman -S --needed --noconfirm "$@"
  elif command -v dnf >/dev/null 2>&1; then
    "${privilege[@]}" dnf install -y "$@"
  elif command -v apt-get >/dev/null 2>&1; then
    "${privilege[@]}" apt-get update
    "${privilege[@]}" apt-get install -y "$@"
  else
    printf 'No supported package manager found (pacman, dnf, apt-get).\n' >&2
    return 1
  fi
}

rc_is_gnome() {
  case "${XDG_CURRENT_DESKTOP:-}:${DESKTOP_SESSION:-}" in
    *GNOME*|*gnome*) return 0 ;;
    *) return 1 ;;
  esac
}
