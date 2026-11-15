#!/bin/sh
set -e
if [ -n "${RC_KEY:-}" ]; then
  mkdir -p ~/.ssh && chmod 700 ~/.ssh
  touch ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys
  blob=$(printf '%s\n' "$RC_KEY" | awk '{ print $2 }')
  grep -qF "$blob" ~/.ssh/authorized_keys || printf '%s\n' "$RC_KEY" >> ~/.ssh/authorized_keys
fi
if [ -n "${RC_ALIAS_ADDRESS:-}" ]; then
  mkdir -p ~/.ssh
  f=~/.ssh/config
  [ -e "$f" ] || (umask 077 && : > "$f")
  tmp=$(mktemp "$f.XXXXXX")
  awk -v h="$RC_ALIAS_NAME" -v ip="$RC_ALIAS_ADDRESS" -v u="$RC_ALIAS_USER" '
tolower($1) == "host" && NF == 2 && $2 == h { print; print "    HostName " ip; print "    User " u; found = 1; inside = 1; next }
tolower($1) == "host" || tolower($1) == "match" { inside = 0 }
inside && (tolower($1) == "hostname" || tolower($1) == "user") { next }
{ print }
END { if (!found) { if (NR) print ""; print "Host " h; print "    HostName " ip; print "    User " u } }
' "$f" > "$tmp"
  cmp -s "$tmp" "$f" || cat "$tmp" > "$f"
  rm -f "$tmp"
fi
if [ -n "${RC_PRINT_KEYS:-}" ]; then
  cat ~/.ssh/authorized_keys
fi
