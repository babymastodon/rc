#!/usr/bin/env bash
set -euo pipefail

SCHEMA="org.gnome.desktop.interface"

current=$(gsettings get "$SCHEMA" color-scheme | tr -d "'")

if [ "$current" = "prefer-dark" ]; then
    gsettings set "$SCHEMA" color-scheme 'default'
else
    gsettings set "$SCHEMA" color-scheme 'prefer-dark'
fi

