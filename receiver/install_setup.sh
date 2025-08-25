#!/usr/bin/env bash
set -euo pipefail

# ---------------------------------------------
# Raspberry Pi 5 SDR stack installer
# - Updates system
# - Enables I2C
# - Installs Gpredict (APT)
# - Installs SDR utils (rtl-sdr, SoapySDR, etc.)
# - Downloads latest SatDump & SDR++ AppImages (aarch64)
# ---------------------------------------------

require_root() {
  if [[ $EUID -ne 0 ]]; then
    echo "Please run as root: sudo $0"
    exit 1
  fi
}

log() { echo -e "\n[+] $*"; }
warn() { echo -e "\n[!] $*" >&2; }
fail() { echo -e "\n[✗] $*" >&2; exit 1; }

require_root

ARCH="$(dpkg --print-architecture || true)"
if [[ "$ARCH" != "arm64" && "$ARCH" != "aarch64" ]]; then
  warn "This script targets arm64/aarch64. Detected: $ARCH. Proceeding anyway."
fi

# ---------- System update ----------
log "Updating system packages…"
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get -y dist-upgrade

# Helpful base tools
apt-get install -y --no-install-recommends \
  curl wget jq ca-certificates git build-essential pkg-config \
  i2c-tools python3-smbus \
  rtl-sdr sox sox-fmt-all \
  soapysdr-module-rtlsdr soapyremote-server \
  gpredict \
  desktop-file-utils fuse libfuse2

# ---------- Enable I2C ----------
log "Enabling I²C interface…"
if command -v raspi-config >/dev/null 2>&1; then
  # 0 = enable in raspi-config noninteractive
  raspi-config nonint do_i2c 0 || warn "raspi-config I²C toggle reported a warning; continuing."
else
  warn "raspi-config not found; ensuring I2C overlays are present in /boot/firmware/config.txt."
  # Minimal fallback: ensure dtparam=i2c_arm=on (Bookworm uses /boot/firmware/config.txt)
  CFG="/boot/firmware/config.txt"
  if [[ -f "$CFG" ]] && ! grep -q '^dtparam=i2c_arm=on' "$CFG"; then
    echo 'dtparam=i2c_arm=on' >> "$CFG"
    log "Added dtparam=i2c_arm=on to $CFG (reboot required)."
  fi
fi

# Add current user (if any) to i2c group
if [[ -n "${SUDO_USER:-}" ]]; then
  usermod -aG i2c "$SUDO_USER" || warn "Could not add $SUDO_USER to i2c group."
fi

# ---------- Optional: RTL-SDR udev fix (disable DVB kernel drivers) ----------
# Prevent kernel DVB driver from grabbing RTL2832U so rtl_sdr/Soapy can use it.
log "Installing RTL-SDR udev rules and blacklisting DVB drivers (optional but recommended)…"
cat >/etc/modprobe.d/rtl-sdr-blacklist.conf <<'EOF'
blacklist dvb_usb_rtl28xxu
blacklist rtl2832
blacklist rtl2830
EOF

cat >/etc/udev/rules.d/20-rtlsdr.rules <<'EOF'
SUBSYSTEMS=="usb", ATTRS{idVendor}=="0bda", ATTRS{idProduct}=="2838", MODE:="0666"
EOF

udevadm control --reload-rules || true
udevadm trigger || true

# ---------- AppImage helper ----------
APPDIR="/opt/appimages"
BINLINK="/usr/local/bin"
mkdir -p "$APPDIR"

download_latest_appimage() {
  local repo="$1"           # e.g., AlexandreRouma/SDRPlusPlus
  local pattern="$2"        # jq regex, e.g., "AppImage.*(aarch64|arm64)"
  local outname="$3"        # filename to save as, e.g., sdrpp.AppImage

  log "Fetching latest AppImage for $repo…"
  local api="https://api.github.com/repos/${repo}/releases/latest"
  local url
  url="$(curl -fsSL "$api" | jq -r --arg pat "$pattern" '
    .assets[]?.browser_download_url | select(test($pat; "i")) | . ' | head -n1)"

  if [[ -z "$url" || "$url" == "null" ]]; then
    warn "No matching AppImage found for $repo with pattern '$pattern'."
    return 1
  fi

  log "Downloading: $url"
  local dest="${APPDIR}/${outname}"
  curl -fL "$url" -o "$dest"
  chmod +x "$dest"

  ln -sf "$dest" "${BINLINK}/${outname%%.AppImage}"  # symlink without .AppImage suffix
  log "Installed ${outname} to $dest and symlinked to ${BINLINK}/${outname%%.AppImage}"
  return 0
}

# ---------- Install SatDump (AppImage) ----------
# Primary repo (most common): SURL/SatDump
# Some forks mirror releases; we prioritize the main project first.
SATDUMP_OK=0
if download_latest_appimage "SURL/SatDump" "AppImage.*(aarch64|arm64)" "satdump.AppImage"; then
  SATDUMP_OK=1
else
  # Fallback: try alternative org name if needed (rare)
  if download_latest_appimage "SatDump/SatDump" "AppImage.*(aarch64|arm64)" "satdump.AppImage"; then
    SATDUMP_OK=1
  fi
fi

if [[ "$SATDUMP_OK" -eq 0 ]]; then
  warn "Could not auto-download SatDump AppImage. You can install later by placing an aarch64 AppImage at $APPDIR/satdump.AppImage and making it executable."
fi

# ---------- Install SDR++ (AppImage) ----------
SDRPP_OK=0
if download_latest_appimage "AlexandreRouma/SDRPlusPlus" "AppImage.*(aarch64|arm64)" "sdrpp.AppImage"; then
  SDRPP_OK=1
fi

if [[ "$SDRPP_OK" -eq 0 ]]; then
  warn "Could not auto-download SDR++ AppImage. You can install later by placing an aarch64 AppImage at $APPDIR/sdrpp.AppImage and making it executable."
fi

# ---------- Desktop entries (optional) ----------
log "Creating desktop entries for SatDump and SDR++ (if AppImages present)…"
DESKDIR="/usr/share/applications"

if [[ -x "$APPDIR/satdump.AppImage" ]]; then
  cat >"${DESKDIR}/satdump.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=SatDump
Exec=${APPDIR}/satdump.AppImage
Icon=satellite
Terminal=false
Categories=HamRadio;Science;AudioVideo;
EOF
fi

if [[ -x "$APPDIR/sdrpp.AppImage" ]]; then
  cat >"${DESKDIR}/sdrpp.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=SDR++
Exec=${APPDIR}/sdrpp.AppImage
Icon=audio-card
Terminal=false
Categories=HamRadio;AudioVideo;Utility;
EOF
fi

# ---------- Final info ----------
log "All done!"

echo -e "\nNext steps / notes:"
echo "• A reboot is recommended to finalize I²C and driver changes: sudo reboot"
echo "• Test I²C:   sudo i2cdetect -y 1"
echo "• Launch apps: satdump   |   sdrpp"
echo "• Gpredict is installed from APT; launch from menu or: gpredict"
echo "• If your RTL-SDR is not detected by user apps, unplug/replug it, or verify that DVB drivers are blacklisted."
