#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_URL="${IT87_REPO_URL:-https://github.com/frankcrawford/it87.git}"
IT87_REF="${IT87_REF:-20f2f2f4c92c14fcdd26f60d050e693ad2c30bf8}"
IT87_REF_NAME="${IT87_REF_NAME:-${IT87_REF:0:7}}"
IT87_DKMS_VERSION="${IT87_DKMS_VERSION:-${IT87_REF_NAME}.trx50-ai-top}"
WORK_DIR="${WORK_DIR:-/tmp/it87-frankcrawford}"
KERNEL_RELEASE="$(uname -r)"
PATCH_FILE="$SCRIPT_DIR/it87-trx50-ai-top.patch"

log()   { printf "\033[1;32m[+]\033[0m %s\n" "$*"; }
warn()  { printf "\033[1;33m[!]\033[0m %s\n" "$*"; }
err()   { printf "\033[1;31m[x]\033[0m %s\n" "$*" >&2; }

validate_work_dir() {
  case "$WORK_DIR" in
    /tmp/it87-*|/var/tmp/it87-*) ;;
    *)
      err "Refusing to remove or reuse unsafe WORK_DIR: $WORK_DIR"
      err "Use a path under /tmp/it87-* or /var/tmp/it87-*."
      exit 1
      ;;
  esac
}

apply_local_patches() {
  if grep -q 'TRX50 AI TOP' "$WORK_DIR/it87.c"; then
    log "TRX50 AI TOP DMI patch already present"
    return
  fi

  if [[ ! -f "$PATCH_FILE" ]]; then
    err "Missing patch file: $PATCH_FILE"
    exit 1
  fi

  log "Applying TRX50 AI TOP DMI patch"
  git -C "$WORK_DIR" apply "$PATCH_FILE"
}

checkout_it87_ref() {
  log "Fetching $IT87_REF"
  if git -C "$WORK_DIR" fetch --depth 1 origin "$IT87_REF"; then
    git -C "$WORK_DIR" checkout --detach FETCH_HEAD
    return
  fi

  if git -C "$WORK_DIR" rev-parse --verify --quiet "${IT87_REF}^{commit}" >/dev/null; then
    warn "Fetch failed; using local commit $IT87_REF"
    git -C "$WORK_DIR" checkout --detach "$IT87_REF"
    return
  fi

  err "Could not fetch or find it87 ref $IT87_REF"
  exit 1
}

unload_it87() {
  if lsmod | awk '{print $1}' | grep -qx it87; then
    rmmod it87
  fi
}

write_modprobe_config() {
  local conf="/etc/modprobe.d/it87.conf"

  if [[ -e "$conf" ]] &&
     ! grep -qx 'options it87 ignore_resource_conflict=1' "$conf" &&
     ! grep -q 'Managed by rc/sensors/install_gigabyte_trx50_it87_dkms.sh' "$conf"; then
    warn "Leaving existing $conf unchanged because it was not created by this installer."
    return
  fi

  cat >"$conf" <<'EOF'
# Managed by rc/sensors/install_gigabyte_trx50_it87_dkms.sh.
# TRX50 AI TOP ACPI conflicts are handled by the local it87 DMI patch.
EOF
}

cleanup_old_dkms_versions() {
  local keep_version="$1"
  local version

  while read -r version; do
    if [[ -z "$version" || "$version" == "$keep_version" ]]; then
      continue
    fi
    warn "Removing older it87 DKMS version $version"
    dkms remove -m it87 -v "$version" --all || warn "Could not remove old it87 DKMS version $version"
  done < <(dkms status -m it87 2>/dev/null | sed -n 's#^it87/\([^,]*\),.*#\1#p' | sort -u)
}

root_install() {
  local src="$1"
  local driver_version="$2"
  local module_path

  if (( EUID != 0 )); then
    err "--root-install must run as root"
    exit 1
  fi

  unload_it87

  if dkms status -m it87 2>/dev/null | grep -Fq "it87/$driver_version,"; then
    dkms remove -m it87 -v "$driver_version" --all
  fi

  DRIVER_VERSION="$driver_version" make -C "$src" dkms
  depmod -a

  module_path="$(modprobe --show-depends it87 | awk '/\/it87\.ko/ {print $2; exit}')"
  if [[ "$module_path" != /lib/modules/"$KERNEL_RELEASE"/extra/it87.ko* ]]; then
    err "Refusing to continue: modprobe it87 does not resolve to the DKMS module."
    err "Resolved path: ${module_path:-none}"
    err "Expected path under: /lib/modules/$KERNEL_RELEASE/extra/"
    exit 1
  fi

  install -d /etc/modprobe.d /etc/modules-load.d
  write_modprobe_config
  printf '%s\n' 'it87' >/etc/modules-load.d/it87.conf

  unload_it87
  modprobe it87
  cleanup_old_dkms_versions "$driver_version"
  dkms status
}

if [[ "${1:-}" == "--root-install" ]]; then
  root_install "${2:?missing source directory}" "${3:?missing DKMS version}"
  exit 0
fi

if [[ "$(uname -s)" != "Linux" ]]; then
  err "install_gigabyte_trx50_it87_dkms.sh only supports Linux."
  exit 1
fi

warn "This installs a third-party it87 kernel module with DKMS."
warn "It also applies a local TRX50 AI TOP DMI patch for expected ACPI resource conflicts."
if [[ "${ASSUME_YES:-}" != "1" ]]; then
  read -r -p "Continue? Type 'yes' to install: " answer
  if [[ "$answer" != "yes" ]]; then
    err "Install canceled."
    exit 1
  fi
fi

missing=()
for pkg in dkms lm_sensors "kernel-devel-$KERNEL_RELEASE" gcc make git; do
  if ! rpm -q "$pkg" >/dev/null 2>&1; then
    missing+=("$pkg")
  fi
done

if (( ${#missing[@]} )); then
  log "Installing packages: ${missing[*]}"
  if command -v pkcon >/dev/null 2>&1; then
    pkcon -y install "${missing[@]}"
  else
    sudo dnf -y install "${missing[@]}"
  fi
fi

validate_work_dir

if [[ -d "$WORK_DIR/.git" ]]; then
  log "Using $WORK_DIR"
else
  rm -rf "$WORK_DIR"
  log "Cloning $REPO_URL into $WORK_DIR"
  git clone --depth 1 "$REPO_URL" "$WORK_DIR"
fi
checkout_it87_ref
apply_local_patches

log "Building test module"
DRIVER_VERSION="$IT87_DKMS_VERSION" make -C "$WORK_DIR"

log "Installing through DKMS via Polkit"
if command -v pkexec >/dev/null 2>&1; then
  pkexec "$SCRIPT_DIR/install_gigabyte_trx50_it87_dkms.sh" --root-install "$WORK_DIR" "$IT87_DKMS_VERSION"
else
  sudo "$SCRIPT_DIR/install_gigabyte_trx50_it87_dkms.sh" --root-install "$WORK_DIR" "$IT87_DKMS_VERSION"
fi

log "Verifying sensors"
if command -v hwstat >/dev/null 2>&1; then
  hwstat --check
else
  "$SCRIPT_DIR/hwstat" --check
fi
