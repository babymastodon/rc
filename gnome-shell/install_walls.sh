#!/usr/bin/env bash
# install_repos.sh — clone or update multiple git repos into a base directory
# Default example includes dharmx/walls into ~/Pictures/walls

set -euo pipefail

# ============================
# Config: list of "URL|dest"
# ============================
REPOS=(
  "https://github.com/dharmx/walls.git|walls"
  "https://github.com/mylinuxforwork/wallpaper.git|wallpaper"
)

# Base directory where each repo's dest folder will be created
BASE_DIR="${HOME}/Pictures"

# Depth for cloning (set to empty for full clone)
GIT_CLONE_DEPTH="--depth 1"

# ============================
# Script
# ============================

echo "Installing/updating ${#REPOS[@]} repositories into: ${BASE_DIR}"
mkdir -p "${BASE_DIR}"

# Check for git
if ! command -v git &>/dev/null; then
  echo "Error: git is not installed. Please install git first."
  exit 1
fi

install_or_update() {
  local repo_url="$1"
  local dest_name="$2"
  local target_dir="${BASE_DIR}/${dest_name}"

  echo ""
  echo "==> ${repo_url} → ${target_dir}"

  if [[ -d "${target_dir}/.git" ]]; then
    echo "Repo exists. Fetching and pulling latest changes..."
    (
      cd "${target_dir}"
      # Be safe and prune stale refs; then fast-forward if possible
      git fetch --all --prune
      # Try main, then master; otherwise just fast-forward current branch
      if git rev-parse --verify origin/main &>/dev/null; then
        git checkout main &>/dev/null || true
        git pull --ff-only origin main
      elif git rev-parse --verify origin/master &>/dev/null; then
        git checkout master &>/dev/null || true
        git pull --ff-only origin master
      else
        git pull --ff-only
      fi
    )
  else
    if [[ -e "${target_dir}" && ! -d "${target_dir}" ]]; then
      echo "Warning: ${target_dir} exists and is not a directory. Skipping."
      return
    fi
    echo "Cloning repository..."
    if [[ -n "${GIT_CLONE_DEPTH}" ]]; then
      git clone ${GIT_CLONE_DEPTH} "${repo_url}" "${target_dir}"
    else
      git clone "${repo_url}" "${target_dir}"
    fi
  fi

  echo "Done: ${dest_name}"
}

# Process each entry
for entry in "${REPOS[@]}"; do
  IFS="|" read -r REPO_URL DEST_NAME <<< "${entry}"
  if [[ -z "${REPO_URL}" || -z "${DEST_NAME}" ]]; then
    echo "Skipping malformed entry: '${entry}' (expected 'URL|dest')"
    continue
  fi
  install_or_update "${REPO_URL}" "${DEST_NAME}"
done

echo ""
echo "All done! Files are located under: ${BASE_DIR}"

