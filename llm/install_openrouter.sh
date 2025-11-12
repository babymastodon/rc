#!/usr/bin/env bash
set -euo pipefail

KEYFILE="${HOME}/.config/openrouter.token"

# Open the OpenRouter API Keys page in the default browser
open_url() {
  local url="https://openrouter.ai/api-keys"
  if command -v xdg-open >/dev/null 2>&1; then xdg-open "$url" >/dev/null 2>&1 &
  elif command -v open >/dev/null 2>&1; then open "$url" >/dev/null 2>&1 &
  else echo "Please visit: $url"
  fi
}

mkdir -p "${HOME}/.config"
touch "$KEYFILE"
chmod 600 "$KEYFILE"

echo "Opening OpenRouter API Keys page so you can create/copy a key…"
open_url
echo
echo "After you copy the key from the page, paste it here."
printf "OpenRouter API key: "
# read silently if possible
if read -r -s KEY; then echo; else read -r KEY; fi

# trim whitespace
KEY="$(printf "%s" "$KEY" | awk '{$1=$1;print}')"

if [ -z "$KEY" ]; then
  echo "No key entered. Aborting." >&2
  exit 1
fi

printf "%s\n" "$KEY" > "$KEYFILE"
chmod 600 "$KEYFILE"

echo "Saved key to $KEYFILE"
echo "Tip: export OPENROUTER_API_KEY=\"\$(cat $KEYFILE)\" in your shell profile."
