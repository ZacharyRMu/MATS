#!/usr/bin/env bash
set -euo pipefail

# --- Helpers ---
pick_pkg() {
  for pkg in "$@"; do
    if apt-cache show "$pkg" >/dev/null 2>&1; then
      echo "$pkg"; return 0
    fi
  done
  return 1
}

# --- Update & prerequisites ---
sudo apt update

# Figure out which libvolk package is available
VOLK_PKG="$(pick_pkg libvolk-dev libvolk2-dev libvolk1-dev || true)"
if [[ -z "${VOLK_PKG}" ]]; then
  echo "No suitable libvolk package found (tried libvolk-dev, libvolk2-dev, libvolk1-dev)."
  exit 1
fi

# OpenCL bits: Intel ICD won't exist on ARM; only include if available
OPENCL_PKGS=(ocl-icd-opencl-dev mesa-opencl-icd)
if apt-cache show intel-opencl-icd >/dev/null 2>&1; then
  OPENCL_PKGS+=("intel-opencl-icd")
fi

# --- Install dependencies ---
sudo apt install -y \
  git build-essential cmake g++ pkgconf \
  libfftw3-dev libpng-dev libtiff-dev libjemalloc-dev libcurl4-openssl-dev \
  "${VOLK_PKG}" libnng-dev libglfw3-dev zenity portaudio19-dev libzstd-dev \
  libhdf5-dev librtlsdr-dev libhackrf-dev libairspy-dev libairspyhf-dev \
  libad9361-dev libiio-dev libbladerf-dev libomp-dev \
  "${OPENCL_PKGS[@]}"

# --- Fonts for satdump-ui (fix Fontconfig errors on minimal Pi images) ---
sudo apt install -y fontconfig fonts-dejavu-core fonts-dejavu-extra fonts-liberation2 fonts-noto-core
fc-cache -f -v || true

# --- Clone or update SatDump ---
if [[ -d SatDump/.git ]]; then
  echo "SatDump already present; updating..."
  git -C SatDump pull --ff-only
else
  git clone https://github.com/SatDump/SatDump.git
fi

# --- Build & install ---
cd SatDump
mkdir -p build && cd build
cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr ..
make -j"$(nproc)"
sudo make install
sudo ldconfig

# Reload udev rules so SDRs work without unplugging
sudo udevadm control --reload-rules || true
sudo udevadm trigger || true

echo "SatDump installed. You can now run: satdump-ui"
# command -v satdump-ui >/dev/null 2>&1 && satdump-ui || true
