#!/usr/bin/env bash
# SatDump one-shot installer for Debian/Ubuntu/Raspberry Pi OS
# Usage:
#   sudo BUILD_GUI=OFF ./install_satdump.sh     # build headless
#   sudo ./install_satdump.sh                   # build with GUI (default)

set -euo pipefail

### ---------- Config ----------
: "${BUILD_GUI:=ON}"                     # ON (default) or OFF
: "${INSTALL_PREFIX:=/usr}"              # where `make install` will place files
: "${SRC_DIR:=/opt/src}"                 # where we'll clone/build
: "${REPO_URL:=https://github.com/SatDump/SatDump.git}"
: "${REPO_DIR:=SatDump}"                 # local folder name
: "${JOBS:=$(nproc)}"
LOGFILE="/var/log/satdump_install.log"

# Determine invoking user for group modifications (when run with sudo)
TARGET_USER="${SUDO_USER:-$USER}"

### ---------- Helpers ----------
log() { echo -e "[*] $*" | tee -a "$LOGFILE"; }
err() { echo -e "[!] $*" | tee -a "$LOGFILE" >&2; }

retry() {
  # retry <n> <cmd...>
  local -r n=$1; shift
  local i=0
  until "$@"; do
    i=$((i+1))
    if (( i >= n )); then return 1; fi
    sleep 2
    log "Retry $i/$n: $*"
  done
}

require_root() {
  if [[ $EUID -ne 0 ]]; then
    err "Please run as root (use sudo)."
    exit 1
  fi
}

### ---------- Start ----------
require_root
mkdir -p "$(dirname "$LOGFILE")"
touch "$LOGFILE"
log "Starting SatDump install at $(date -Is). BUILD_GUI=$BUILD_GUI"

# Noninteractive apt
export DEBIAN_FRONTEND=noninteractive
retry 3 apt-get update | tee -a "$LOGFILE"
# Optionally upgrade core packages (comment out if you prefer not to)
# retry 3 apt-get -y dist-upgrade | tee -a "$LOGFILE"

# Base build tools & libs
BASE_PKGS=(
  git build-essential cmake ninja-build pkgconf curl ca-certificates
  g++ libfftw3-dev libpng-dev libtiff-dev libjemalloc-dev
  libcurl4-openssl-dev libnng-dev libzstd-dev libhdf5-dev
  librtlsdr-dev libhackrf-dev libairspy-dev libairspyhf-dev
  libad9361-dev libiio-dev libbladerf-dev libomp-dev
  ocl-icd-opencl-dev intel-opencl-icd mesa-opencl-icd
)

GUI_PKGS=( libglfw3-dev zenity )

# Handle libvolk package name differences across distros
VOLK_CANDIDATES=( libvolk2-dev libvolk-dev volk libvolk1-dev )
VOLK_PKG=""
for cand in "${VOLK_CANDIDATES[@]}"; do
  if apt-cache show "$cand" >/dev/null 2>&1; then
    VOLK_PKG="$cand"
    break
  fi
done
if [[ -z "$VOLK_PKG" ]]; then
  err "No suitable VOLK dev package found via apt. Will build VOLK from source."
  BUILD_VOLK_FROM_SOURCE=1
else
  BUILD_VOLK_FROM_SOURCE=0
  BASE_PKGS+=("$VOLK_PKG")
fi

# Install packages
ALL_PKGS=("${BASE_PKGS[@]}")
if [[ "$BUILD_GUI" == "ON" ]]; then
  ALL_PKGS+=("${GUI_PKGS[@]}")
fi

log "Installing packages: ${ALL_PKGS[*]}"
retry 3 apt-get install -y --no-install-recommends "${ALL_PKGS[@]}" | tee -a "$LOGFILE"

# Build VOLK from source if needed
if (( BUILD_VOLK_FROM_SOURCE )); then
  log "Building VOLK from source..."
  mkdir -p "$SRC_DIR"
  cd "$SRC_DIR"
  if [[ ! -d volk ]]; then
    retry 3 git clone --depth 1 https://github.com/gnuradio/volk.git | tee -a "$LOGFILE"
  else
    (cd volk && git fetch --depth 1 origin && git reset --hard origin/master) | tee -a "$LOGFILE"
  fi
  cmake -S volk -B volk/build -G Ninja -DCMAKE_BUILD_TYPE=Release
  cmake --build volk/build -j "$JOBS" | tee -a "$LOGFILE"
  cmake --install volk/build | tee -a "$LOGFILE"
  ldconfig
  log "VOLK built and installed."
fi

# Ensure source directory exists
mkdir -p "$SRC_DIR"
cd "$SRC_DIR"

# Clone or update SatDump
if [[ ! -d "$REPO_DIR/.git" ]]; then
  log "Cloning SatDump..."
  retry 3 git clone --depth 1 "$REPO_URL" "$REPO_DIR" | tee -a "$LOGFILE"
else
  log "Updating existing SatDump clone..."
  (cd "$REPO_DIR" && git fetch --depth 1 origin && git reset --hard origin/master) | tee -a "$LOGFILE"
fi

# Configure & build
cd "$REPO_DIR"
mkdir -p build
cd build

CMAKE_FLAGS=(
  -DCMAKE_BUILD_TYPE=Release
  "-DCMAKE_INSTALL_PREFIX=${INSTALL_PREFIX}"
  -DBUILD_GUI="$BUILD_GUI"
)

log "Configuring with CMake (Ninja)..."
cmake .. -G Ninja "${CMAKE_FLAGS[@]}" | tee -a "$LOGFILE"

log "Building SatDump with $JOBS jobs..."
cmake --build . -j "$JOBS" | tee -a "$LOGFILE"

log "Installing SatDump to $INSTALL_PREFIX (system-wide)..."
cmake --install . | tee -a "$LOGFILE"
ldconfig

# Udev rules / group access: install utilities that bring rules & add user to groups
log "Setting SDR udev rules and user group access (rtl-sdr, hackrf, airspy, bladerf)..."
retry 3 apt-get install -y --no-install-recommends \
  rtl-sdr hackrf airspyhf-tools bladerf | tee -a "$LOGFILE" || true

# Some distros use plugdev; others rely on 'dialout' or custom groups
for grp in plugdev dialout; do
  if getent group "$grp" >/dev/null; then
    usermod -aG "$grp" "$TARGET_USER" || true
  fi
done

# Desktop entry for GUI (if built)
if [[ "$BUILD_GUI" == "ON" ]]; then
  DESKTOP_FILE="/usr/share/applications/satdump.desktop"
  if [[ ! -f "$DESKTOP_FILE" ]]; then
    log "Creating desktop launcher at $DESKTOP_FILE"
    cat >/usr/share/applications/satdump.desktop <<'EOF'
[Desktop Entry]
Type=Application
Name=SatDump
Comment=Satellite data decoder and processor
Exec=satdump
Terminal=false
Categories=Science;Utility;
StartupNotify=false
EOF
  fi
fi

# Quick sanity checks
log "Verifying installation..."
if command -v satdump >/dev/null 2>&1; then
  satdump --version 2>&1 | tee -a "$LOGFILE" || true
else
  err "satdump not found in PATH after install."
fi

log "Done! You may need to log out/in (or reboot) for new group permissions to take effect."
log "Install log saved to: $LOGFILE"
