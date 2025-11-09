#!/usr/bin/env bash
# merge-gnome-shortcuts.sh
# Manage BOTH GNOME built-in keybindings and custom shortcuts in one pass.
# - Built-in keybindings use entries: "schema|key|accelerator"
# - Custom shortcuts use entries: "Name|Command|Accelerator"
#
# Idempotent:
# - Built-in keys: updated only if different; prints old/new.
# - Custom keys: de-duplicated by (Name|Command). If only binding differs, it's updated.

set -euo pipefail

# ─────────────────────────────────────────────────────────────────────────────
# ✏️ EDIT THESE LISTS
# GNOME built-in keybindings (schema|key|accelerator)
#   Example: "org.gnome.shell.keybindings|toggle-overview|<Super>slash"
GNOME_SHORTCUTS=(
  "org.gnome.shell.keybindings|toggle-overview|<Super>slash"
  # "org.gnome.desktop.wm.keybindings|switch-to-workspace-left|<Super>Left"
  # "org.gnome.desktop.wm.keybindings|switch-to-workspace-right|<Super>Right"
)

# Custom shortcuts (Name|Command|Accelerator)
#   Example: "Toggle Dark Mode|$HOME/.local/bin/toggle-dark-mode.sh|<Super>d"
CUSTOM_SHORTCUTS=(
  "Toggle Dark Mode|$HOME/.local/bin/toggle-dark-mode.sh|<Super>d"
  # "Open Terminal|gnome-terminal|<Super>Return"
)
# ─────────────────────────────────────────────────────────────────────────────

# ── Built-in keybindings helpers ─────────────────────────────────────────────
wrap_as_array() {
  # If value already looks like a GNOME array (starts with '['), keep it.
  # Otherwise wrap a single accelerator like <Super>slash into "['<Super>slash']"
  local v="$1"
  if [[ "$v" =~ ^\[.*\]$ ]]; then
    echo "$v"
  else
    echo "['$v']"
  fi
}

apply_gnome_shortcuts() {
  local created=0 updated=0 skipped=0 # (created not really used for built-in)

  echo "=== GNOME built-in keybindings ==="
  for entry in "${GNOME_SHORTCUTS[@]}"; do
    IFS='|' read -r SCHEMA KEY ACCEL <<< "$entry"
    local_new="$(wrap_as_array "$ACCEL")"

    echo "➡️  ${SCHEMA}.${KEY}"
    # Read existing
    if ! existing="$(gsettings get "$SCHEMA" "$KEY" 2>/dev/null)"; then
      echo "   ⚠️  Cannot read current value (schema/key may not exist). Skipping."
      ((skipped++)) || true
      echo
      continue
    fi
    echo "   Current: $existing"
    echo "   Desired: $local_new"

    if [[ "$existing" == "$local_new" ]]; then
      echo "   ↪️  No change needed."
      ((skipped++)) || true
    else
      if gsettings set "$SCHEMA" "$KEY" "$local_new" 2>/dev/null; then
        verify="$(gsettings get "$SCHEMA" "$KEY")"
        if [[ "$verify" == "$local_new" ]]; then
          echo "   ✅ Updated."
          ((updated++)) || true
        else
          echo "   ⚠️  Mismatch after applying (got: $verify)."
        fi
      else
        echo "   ❌ Failed to set value."
      fi
    fi
    echo
  done

  echo "Built-in summary: Updated=$updated, Unchanged=$skipped"
  echo
}

# ── Custom shortcuts helpers ─────────────────────────────────────────────────
PLUGIN_SCHEMA="org.gnome.settings-daemon.plugins.media-keys"
BINDING_SCHEMA="org.gnome.settings-daemon.plugins.media-keys.custom-keybinding"
LIST_KEY="custom-keybindings"
BASE_PATH="/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings"

get_paths() {
  local raw
  raw="$(gsettings get "$PLUGIN_SCHEMA" "$LIST_KEY")" || raw="[]"
  grep -oE "'[^']+'" <<<"$raw" | tr -d "'" || true
}

contains() {
  local needle="$1"; shift || true
  local x
  for x in "$@"; do
    [[ "$x" == "$needle" ]] && return 0
  done
  return 1
}

next_free_path() {
  local -a used=("$@")
  local n=0 candidate
  while :; do
    candidate="${BASE_PATH}/custom${n}/"
    if ! contains "$candidate" "${used[@]}"; then
      echo "$candidate"
      return 0
    fi
    ((n++))
  done
}

get_kb_value() {
  local path="$1" key="$2"
  gsettings get "${BINDING_SCHEMA}:${path}" "$key"
}

set_kb_value() {
  local path="$1" key="$2" value="$3"
  gsettings set "${BINDING_SCHEMA}:${path}" "$key" "$value"
}

write_path_list() {
  local -a arr=("$@")
  if ((${#arr[@]}==0)); then
    gsettings set "$PLUGIN_SCHEMA" "$LIST_KEY" "[]"
    return
  fi
  local joined="['$(printf "%s','" "${arr[@]}" | sed "s/','$//")']"
  gsettings set "$PLUGIN_SCHEMA" "$LIST_KEY" "$joined"
}

unquote() {
  local s="$1"
  [[ "$s" =~ ^\'(.*)\'$ ]] && echo "${BASH_REMATCH[1]}" || echo "$s"
}

apply_custom_shortcuts() {
  echo "=== GNOME custom shortcuts ==="

  mapfile -t PATHS < <(get_paths)

  # Index existing by "Name|Command"
  declare -A EXISTING_BY_KEY
  declare -A EXISTING_BINDING_BY_PATH

  for p in "${PATHS[@]}"; do
    if ! name_raw=$(get_kb_value "$p" "name" 2>/dev/null); then
      continue
    fi
    cmd_raw=$(get_kb_value "$p" "command" 2>/dev/null || echo "''")
    bind_raw=$(get_kb_value "$p" "binding" 2>/dev/null || echo "''")

    name=$(unquote "$name_raw")
    cmd=$(unquote "$cmd_raw")
    binding=$(unquote "$bind_raw")

    EXISTING_BY_KEY["$name|$cmd"]="$p"
    EXISTING_BINDING_BY_PATH["$p"]="$binding"
  done

  local created=0 updated=0 skipped=0

  for entry in "${CUSTOM_SHORTCUTS[@]}"; do
    IFS='|' read -r NAME COMMAND ACCEL <<< "$entry"
    NAME_Q="'$NAME'"
    COMMAND_Q="'$COMMAND'"
    BINDING_Q="'$ACCEL'"
    key="$NAME|$COMMAND"

    if [[ -n "${EXISTING_BY_KEY[$key]:-}" ]]; then
      path="${EXISTING_BY_KEY[$key]}"
      current_binding="${EXISTING_BINDING_BY_PATH[$path]:-}"
      echo "• \"$NAME\" already exists at $path"
      echo "   Command: $COMMAND"
      echo "   Current binding: ${current_binding:-<none>}"
      echo "   Desired binding: $ACCEL"

      if [[ "$current_binding" != "$ACCEL" ]]; then
        set_kb_value "$path" "binding" "$BINDING_Q"
        new_binding=$(unquote "$(get_kb_value "$path" "binding")")
        if [[ "$new_binding" == "$ACCEL" ]]; then
          echo "   ✅ Updated binding."
          ((updated++)) || true
        else
          echo "   ⚠️  Attempted update, now: $new_binding"
        fi
      else
        echo "   ↪️  No change needed."
        ((skipped++)) || true
      fi
      echo
      continue
    fi

    new_path="$(next_free_path "${PATHS[@]}")"
    echo "• Creating \"$NAME\" at $new_path"
    echo "   Command: $COMMAND"
    echo "   Binding: $ACCEL"

    set_kb_value "$new_path" "name" "$NAME_Q"
    set_kb_value "$new_path" "command" "$COMMAND_Q"
    set_kb_value "$new_path" "binding" "$BINDING_Q"

    PATHS+=("$new_path")
    write_path_list "${PATHS[@]}"

    v_name=$(unquote "$(get_kb_value "$new_path" "name")")
    v_cmd=$(unquote "$(get_kb_value "$new_path" "command")")
    v_bind=$(unquote "$(get_kb_value "$new_path" "binding")")
    if [[ "$v_name" == "$NAME" && "$v_cmd" == "$COMMAND" && "$v_bind" == "$ACCEL" ]]; then
      echo "   ✅ Created successfully."
      ((created++)) || true
      EXISTING_BY_KEY["$key"]="$new_path"
      EXISTING_BINDING_BY_PATH["$new_path"]="$ACCEL"
    else
      echo "   ❌ Creation verification failed (got: name=\"$v_name\", command=\"$v_cmd\", binding=\"$v_bind\")"
    fi
    echo
  done

  echo "Custom summary: Created=$created, Updated=$updated, Unchanged=$skipped"
  echo
}

# ── Run both sections ───────────────────────────────────────────────────────
apply_gnome_shortcuts
apply_custom_shortcuts

echo "All done."

