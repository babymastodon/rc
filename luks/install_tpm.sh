#!/usr/bin/env bash
set -euo pipefail

ask() { local p="${1:-Proceed?}" d="${2:-n}" a; while true; do
  read -r -p "$p [y/N]: " a || exit 1
  a="${a,,}"; [[ -z "$a" ]] && a="$d"
  case "$a" in y|yes) return 0;; n|no) return 1;; *) echo "Please answer y or n.";; esac
done; }

die(){ echo "ERROR: $*" >&2; exit 1; }

[[ $EUID -eq 0 ]] || die "Run as root (sudo)."
command -v cryptsetup >/dev/null || die "cryptsetup not found"
command -v systemd-cryptenroll >/dev/null || die "systemd-cryptenroll not found"

echo "==> Detecting LUKS device (FSTYPE=crypto_LUKS)…"
mapfile -t CANDIDATES < <(lsblk -pn -o NAME,FSTYPE -P | awk -F'"' '/FSTYPE="crypto_LUKS"/ {print $2}')

[[ ${#CANDIDATES[@]} -gt 0 ]] || die "No LUKS device found."

if (( ${#CANDIDATES[@]} == 1 )); then
  DEV="${CANDIDATES[0]}"
else
  echo "Multiple LUKS devices found:"
  for i in "${!CANDIDATES[@]}"; do echo " $((i+1)). ${CANDIDATES[$i]}"; done
  read -r -p "Choose device number: " n
  [[ "$n" =~ ^[0-9]+$ ]] && (( n>=1 && n<=${#CANDIDATES[@]} )) || die "Invalid selection."
  DEV="${CANDIDATES[$((n-1))]}"
fi

echo "Using: $DEV"
echo
echo "==> Checking LUKS version…"
VER="$(cryptsetup luksDump "$DEV" | sed -n 's/^Version:[[:space:]]*\([0-9]\+\).*/\1/p' | head -n1)"
[[ "$VER" == "2" ]] || die "Device is LUKS$VER; TPM2 enrollment requires LUKS2."

echo
echo "==> Inspecting current tokens…"
cryptsetup luksDump "$DEV" | sed -n '/^Tokens:/,/^Keyslots:/p' || true

if cryptsetup luksDump "$DEV" | grep -q 'systemd-tpm2'; then
  echo "TPM2 token detected on $DEV."
  if ask "Wipe existing TPM2 token?" "y"; then
    systemd-cryptenroll --wipe-slot=tpm2 "$DEV"
    echo "TPM2 token wiped."
  else
    echo "Keeping existing TPM2 token."
  fi
else
  echo "No TPM2 token currently enrolled."
fi

echo
echo "==> Enrolling TPM2 (PCRs=7)…"
systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=7 "$DEV"

echo
echo "==> Verifying new tokens…"
cryptsetup luksDump "$DEV" | sed -n '/^Tokens:/,/^Keyslots:/p' || true

if command -v dracut >/dev/null; then
  echo
  if ask "Rebuild initramfs now (dracut --force)?" "y"; then
    dracut --force
    echo "dracut completed."
  else
    echo "Skipped dracut."
  fi
else
  echo "dracut not found; skipping initramfs rebuild."
fi

echo
echo "✅ Done. Reboot to test TPM2 auto-unlock."

