#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

case "$(uname -s)" in
  Darwin)
    exec "$SCRIPT_DIR/install_voxtype_mac.sh" "$@"
    ;;
  Linux)
    exec "$SCRIPT_DIR/install_voxtype_linux.sh" "$@"
    ;;
  *)
    printf "\033[1;31m[x]\033[0m Unsupported OS: %s\n" "$(uname -s)" >&2
    exit 1
    ;;
esac
