#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# Dropbox selective sync TUI (quick, no waiting)
# - Shows top-level folders and exclusion status
# - Toggle individual folders, exclude/include all, refresh
# - Fails fast if Dropbox daemon is not running or exclusions empty
# ============================================================

log()   { printf "\033[1;32m[+]\033[0m %s\n" "$*"; }
warn()  { printf "\033[1;33m[!]\033[0m %s\n" "$*"; }
err()   { printf "\033[1;31m[x]\033[0m %s\n" "$*" >&2; }

XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
dropbox_cli_default="$HOME/.local/bin/dropbox"
DROPBOX_CMD="${DROPBOX_CMD:-${dropbox_cli_default}}"

if ! command -v "$DROPBOX_CMD" >/dev/null 2>&1; then
  if command -v dropbox >/dev/null 2>&1; then
    DROPBOX_CMD="dropbox"
  else
    err "Dropbox CLI not found (looked for $DROPBOX_CMD and dropbox). Run install.sh first."
    exit 1
  fi
fi

dropbox_info_json="$HOME/.dropbox/info.json"

declare -A excluded_map
top_level_dirs=()
root=""
root_real=""

realpath_safe() {
  if command -v realpath >/dev/null 2>&1; then
    realpath -m "$1"
  else
    python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$1"
  fi
}

get_dropbox_root() {
  if [[ -f "$dropbox_info_json" ]]; then
    local path
    path="$(tr -d '\n' <"$dropbox_info_json" \
      | sed -n 's/.*"personal":[^}]*"path":[[:space:]]*"\([^"]*\)".*/\1/p' || true)"
    if [[ -n "$path" ]]; then
      printf '%s\n' "$path"
      return
    fi
  fi
  printf '%s\n' "$HOME/Dropbox"
}

require_running() {
  local output status=0
  output="$("$DROPBOX_CMD" status 2>&1)" || status=$?
  if ((status != 0)) || [[ "$output" =~ [Nn]ot[[:space:]]+running ]] || [[ "$output" =~ "isn.t running" ]]; then
    err "Dropbox daemon not running. Start it (dropbox start -i) then rerun."
    exit 1
  fi
}

load_excluded_map() {
  excluded_map=()
  local output line
  if ! output="$("$DROPBOX_CMD" exclude list 2>/dev/null)"; then
    err "Failed to fetch exclusion list."
    exit 1
  fi

  while IFS= read -r line; do
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"
    [[ -z "$line" ]] && continue
    [[ "$line" =~ ^[Ee]xcluded:?$ ]] && continue

    local abs=""
    if [[ "$line" == /* ]]; then
      abs="$(realpath_safe "$line")"
    else
      # Try resolving relative to root; if it escapes, fall back to suffix after "Dropbox/".
      local candidate
      candidate="$(realpath_safe "$root_real/$line")"
      if [[ "$candidate" == "$root_real"* ]]; then
        abs="$candidate"
      else
        # Extract tail after last occurrence of "Dropbox/" (common in CLI output).
        local suffix="$line"
        if [[ "$suffix" == *"Dropbox/"* ]]; then
          suffix="${suffix##*Dropbox/}"
        fi
        [[ -z "$suffix" ]] && continue
        abs="$(realpath_safe "$root_real/$suffix")"
      fi
    fi

    [[ -z "$abs" ]] && continue
    excluded_map["$abs"]=1
  done <<<"$output"

  if ((${#excluded_map[@]} == 0)); then
    err "No exclusions found from 'dropbox exclude list'. Ensure daemon is running and exclusions are set."
    exit 1
  fi
}

collect_top_level() {
  top_level_dirs=()
  local -A seen=()

  while IFS= read -r d; do
    [[ -z "$d" ]] && continue
    [[ "$d" == ".dropbox.cache" ]] && continue
    # Skip any entries that are not plain directory names (defense).
    [[ "$d" == *"/"* ]] && continue
    [[ "$d" == "." || "$d" == ".." ]] && continue
    seen["$d"]=1
    top_level_dirs+=("$d")
  done < <(find "$root_real" -mindepth 1 -maxdepth 1 -type d -printf '%P\n' | sort)

  for path in "${!excluded_map[@]}"; do
    if [[ "$path" == "$root_real" ]]; then
      continue
    elif [[ "$path" == "$root_real/"* ]]; then
      local rel="${path#$root_real/}"
      rel="${rel%%/*}"
      [[ -z "$rel" ]] && continue
      [[ "$rel" == ".dropbox.cache" ]] && continue
      [[ "$rel" == *"/"* ]] && continue
      [[ "$rel" == "." || "$rel" == ".." ]] && continue
      if [[ -z "${seen[$rel]:-}" ]]; then
        seen["$rel"]=1
        top_level_dirs+=("$rel")
      fi
    fi
  done

  IFS=$'\n' top_level_dirs=($(printf '%s\n' "${top_level_dirs[@]}" | sort -u))
}

print_status() {
  echo
  log "Dropbox root: $root_real"
  log "Folders:"
  if ((${#top_level_dirs[@]} == 0)); then
    log "  (none detected)"
  else
    local idx=1
    for d in "${top_level_dirs[@]}"; do
      [[ "$d" == ".dropbox.cache" ]] && continue
      [[ "$d" == *"/"* ]] && continue
      [[ "$d" == "." || "$d" == ".." ]] && continue
      local path
      path="$(realpath_safe "$root_real/$d")"
      local mark="[ ]"
      local status=""
      if [[ -n "${excluded_map[$path]:-}" ]]; then
        mark="[X]"
        status="(excluded)"
      fi
      printf "  %2d. %s %s %s\n" "$idx" "$mark" "$d" "$status"
      ((idx++))
    done
  fi
  echo
}

toggle_folder() {
  local folder="$1"
  local path
  path="$(realpath_safe "$root_real/$folder")"
  if [[ -n "${excluded_map[$path]:-}" ]]; then
    log "Including: $folder"
    if "$DROPBOX_CMD" exclude remove "$path"; then
      unset 'excluded_map[$path]'
    else
      warn "Failed to include $folder"
    fi
  else
    log "Excluding: $folder"
    if "$DROPBOX_CMD" exclude add "$path"; then
      excluded_map["$path"]=1
    else
      warn "Failed to exclude $folder"
    fi
  fi
}

set_all() {
  local mode="$1" # exclude|include
  for d in "${top_level_dirs[@]}"; do
    [[ "$d" == ".dropbox.cache" ]] && continue
    local path
    path="$(realpath_safe "$root_real/$d")"
    if [[ "$mode" == "exclude" ]]; then
      "$DROPBOX_CMD" exclude add "$path" || warn "Failed to exclude $d"
    else
      "$DROPBOX_CMD" exclude remove "$path" || warn "Failed to include $d"
    fi
  done
  load_excluded_map
}

refresh_state() {
  require_running
  load_excluded_map
  collect_top_level
}

main_loop() {
  while true; do
    print_status
    read -r -p "Action ([number]=toggle, d=exclude all, e=include all, r=refresh, q=quit): " choice
    case "$choice" in
      q|quit) exit 0 ;;
      r|"") refresh_state ;;
      d) set_all "exclude" ;;
      e) set_all "include" ;;
      *)
        if [[ "$choice" =~ ^[0-9]+$ ]]; then
          local idx=$((choice - 1))
    if ((idx < 0 || idx >= ${#top_level_dirs[@]})); then
      warn "Invalid selection."
    else
      local target="${top_level_dirs[$idx]}"
      [[ "$target" == ".dropbox.cache" ]] && { warn "Cannot toggle .dropbox.cache"; continue; }
      toggle_folder "$target"
      load_excluded_map
    fi
  else
    warn "Unknown choice."
        fi
        ;;
    esac
  done
}

log "=== Dropbox selective sync TUI ==="

root="$(get_dropbox_root)"
root_real="$(realpath_safe "$root")"
if [[ ! -d "$root_real" ]]; then
  err "Dropbox root '$root_real' does not exist. Start Dropbox and try again."
  exit 1
fi

refresh_state
main_loop
