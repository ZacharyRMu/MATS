#!/usr/bin/env bash
# Install SDR++ from a .deb in the same directory as this script

set -euo pipefail

: "${DEBIAN_FRONTEND:=noninteractive}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOGFILE="/var/log/sdrpp_install.log"
mkdir -p "$(dirname "$LOGFILE")"; touch "$LOGFILE"

log(){ echo "[*] $*" | tee -a "$LOGFILE"; }
err(){ echo "[!] $*" | tee -a "$LOGFILE" >&2; }

[[ $EUID -eq 0 ]] || { err "Run with sudo/root"; exit 1; }

# Find a .deb in the script's directory
shopt -s nullglob
DEBS=("$SCRIPT_DIR"/*.deb)
shopt -u nullglob

if [[ ${#DEBS[@]} -eq 0 ]]; then
  err "No .deb package found in $SCRIPT_DIR"
  exit 1
elif [[ ${#DEBS[@]} -gt 1 ]]; then
  err "Multiple .deb files found; please keep only one in $SCRIPT_DIR"
  printf '  %s\n' "${DEBS[@]}"
  exit 1
fi

PKG="${DEBS[0]}"
log "Found package: $PKG"

# Verify arch matches
SYS_ARCH="$(dpkg --print-architecture)"
PKG_ARCH="$(dpkg-deb -f "$PKG" Architecture || echo unknown)"
PKG_NAME="$(dpkg-deb -f "$PKG" Package || echo unknown)"
PKG_VER="$(dpkg-deb -f "$PKG" Version || echo unknown)"
log "Package: $PKG_NAME $PKG_VER ($PKG_ARCH), System: $SYS_ARCH"

if [[ "$PKG_ARCH" != "all" && "$PKG_ARCH" != "$SYS_ARCH" ]]; then
  err "Architecture mismatch: package=$PKG_ARCH system=$SYS_ARCH"
  exit 1
fi

# Update package index
apt-get update -y | tee -a "$LOGFILE"

# Install (apt-get will resolve dependencies automatically with ./ prefix)
log "Installing $PKG_NAME..."
if ! apt-get install -y "./$PKG" | tee -a "$LOGFILE"; then
  err "Direct install failed; trying dpkg + fix"
  dpkg -i "$PKG" | tee -a "$LOGFILE" || true
  apt-get -f install -y | tee -a "$LOGFILE"
fi

# Check installation
if command -v sdrpp >/dev/null 2>&1; then
  log "sdrpp installed at: $(command -v sdrpp)"
else
  log "Package installed, but no 'sdrpp' in PATH. Might be a GUI-only package."
fi

log "Done. Install log: $LOGFILE"
