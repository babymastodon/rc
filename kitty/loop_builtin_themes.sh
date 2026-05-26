#!/usr/bin/env bash
set -euo pipefail

delay="${1:-1}"
cache_age="${KITTY_THEMES_CACHE_AGE:-1}"
listen_on="${KITTY_LISTEN_ON:-${KITTY_THEME_LISTEN_ON:-unix:/tmp/kitty}}"
theme_file="$(mktemp "${TMPDIR:-/tmp}/kitty-theme.XXXXXX.conf")"

cleanup() {
  rm -f "$theme_file"
}
trap cleanup EXIT

usage() {
  cat <<'EOF'
Usage: loop_builtin_themes.sh [delay_seconds]

Loops through Kitty's built-in themes and applies a new theme every delay_seconds.
Defaults to 1 second.

Environment:
  KITTY_THEME_LISTEN_ON     Remote-control socket when not run inside Kitty.
                            Defaults to unix:/tmp/kitty.
  KITTY_THEMES_CACHE_AGE    Cache age passed to `kitty +kitten themes`.
                            Defaults to 1 day.
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

if ! command -v kitty >/dev/null 2>&1; then
  echo "kitty is not installed or not on PATH" >&2
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 is required to read Kitty's theme metadata" >&2
  exit 1
fi

if [[ ! "$delay" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
  echo "delay must be a number of seconds" >&2
  exit 1
fi

# Ensure Kitty has a local copy of its theme metadata. The negative cache age
# avoids network access after the cache exists.
if ! kitty +kitten themes --cache-age "$cache_age" --dump-theme "Monokai" >/dev/null; then
  echo "Could not load Kitty themes. Try running: kitty +kitten themes" >&2
  exit 1
fi

mapfile -t themes < <(
  python3 - <<'PY'
import json
import os
import zipfile

cache = os.path.expanduser("~/.cache/kitty/kitty-themes.zip")
with zipfile.ZipFile(cache) as zf:
    metadata_name = next(
        name for name in zf.namelist()
        if name.endswith("/themes.json")
    )
    themes = json.loads(zf.read(metadata_name))

for theme in sorted(item["name"] for item in themes):
    print(theme)
PY
)

if ((${#themes[@]} == 0)); then
  echo "No Kitty themes found" >&2
  exit 1
fi

echo "Looping ${#themes[@]} Kitty themes every ${delay}s. Press Ctrl-C to stop."

while true; do
  for theme in "${themes[@]}"; do
    printf 'Applying: %s\n' "$theme"
    if kitty +kitten themes --cache-age -1 --dump-theme "$theme" >"$theme_file"; then
      kitty @ --to "$listen_on" set-colors --all --configured "$theme_file"
    else
      printf 'Skipping failed theme: %s\n' "$theme" >&2
    fi
    sleep "$delay"
  done
done
