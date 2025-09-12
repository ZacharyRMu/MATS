#!/usr/bin/env bash
set -euo pipefail

# Raspberry Pi 5 quick SDR stack installer (arm64 / Bookworm)
# - Expects satdump*.deb and sdrpp*.deb in the SAME directory as this script

# ---------- helpers ----------
need_root(){ [[ $EUID -eq 0 ]] || { echo "Please run as root: sudo $0" >&2; exit 1; }; }
log(){  echo -e "\n[+] $*"; }
warn(){ echo -e "\n[!] $*" >&2; }
fail(){ echo -e "\n[✗] $*" >&2; exit 1; }
retry(){ local n=$1; shift; local i=0; until "$@"; do ((i++)); ((i>=n)) && return 1; sleep 2; done; }

need_root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ARCH="$(dpkg --print-architecture || true)"
[[ "$ARCH" == "arm64" || "$ARCH" == "aarch64" ]] || warn "This targets arm64; detected: $ARCH (continuing)."

# ---------- system update ----------
log "Updating & upgrading system packages…"
retry 3 apt-get update
DEBIAN_FRONTEND=noninteractive retry 3 apt-get -y dist-upgrade

# ---------- base tools ----------
log "Installing base tools & I²C utilities…"
retry 3 apt-get install -y --no-install-recommends \
  ca-certificates curl git jq \
  i2c-tools python3-smbus

# ---------- enable I²C ----------
log "Enabling I²C interface…"
if command -v raspi-config >/dev/null 2>&1; then
  raspi-config nonint do_i2c 0 || warn "raspi-config reported a warning; continuing."
else
  # Bookworm uses /boot/firmware/config.txt
  CFG="/boot/firmware/config.txt"
  if [[ -f "$CFG" ]] && ! grep -q '^dtparam=i2c_arm=on' "$CFG"; then
    echo 'dtparam=i2c_arm=on' >> "$CFG"
    log "Appended dtparam=i2c_arm=on to $CFG (reboot required)."
  fi
fi
# Add invoking user to i2c group (if available)
[[ -n "${SUDO_USER:-}" ]] && usermod -aG i2c "$SUDO_USER" || true

# ---------- RTL-SDR (V4) utilities ----------
# Installs standard rtl-sdr tools (rtl_test, rtl_fm, rtl_eeprom, etc.),
# adds permissive udev rule, and blacklists DVB kernel grabbers.
log "Installing RTL-SDR utilities & setting udev/blacklist…"
retry 3 apt-get install -y --no-install-recommends rtl-sdr

# Blacklist kernel DVB drivers so userspace tools can claim the dongle
cat >/etc/modprobe.d/rtl-sdr-blacklist.conf <<'EOF'
blacklist dvb_usb_rtl28xxu
blacklist rtl2832
blacklist rtl2830
EOF

# Simple udev rule for Realtek 0bda:2838 (common RTL2832U VID/PID)
cat >/etc/udev/rules.d/20-rtlsdr.rules <<'EOF'
SUBSYSTEMS=="usb", ATTRS{idVendor}=="0bda", ATTRS{idProduct}=="2838", MODE:="0666"
EOF

udevadm control --reload-rules || true
udevadm trigger || true

# ---------- install local .debs (SatDump + SDR++) ----------
install_deb(){
  local deb="$1"
  local sys_arch pkg_arch pkg_name pkg_ver
  sys_arch="$(dpkg --print-architecture)"
  pkg_arch="$(dpkg-deb -f "$deb" Architecture || echo unknown)"
  pkg_name="$(dpkg-deb -f "$deb" Package || echo unknown)"
  pkg_ver="$(dpkg-deb -f "$deb" Version || echo unknown)"
  log "Installing $pkg_name $pkg_ver ($pkg_arch) from: $deb"

  if [[ "$pkg_arch" != "all" && "$pkg_arch" != "$sys_arch" ]]; then
    fail "Architecture mismatch: package=$pkg_arch system=$sys_arch"
  fi
  retry 3 apt-get update
  # Use apt to resolve dependencies automatically
  if ! apt-get install -y "./$deb"; then
    warn "apt direct install failed; trying dpkg + fix."
    dpkg -i "$deb" || true
    apt-get -f install -y
  fi
}

choose_deb(){
  # choose lexicographically last (often newest) among matches
  local pattern="$1"
  shopt -s nullglob
  mapfile -t files < <(cd "$SCRIPT_DIR" && ls -1 $pattern 2>/dev/null || true)
  shopt -u nullglob
  [[ ${#files[@]} -gt 0 ]] || return 1
  printf '%s\n' "${files[@]}" | sort | tail -n1
}

log "Looking for local SatDump .deb (satdump*.deb)…"
SATDUMP_DEB_REL="$(choose_deb 'satdump*.deb' || true)"
if [[ -n "${SATDUMP_DEB_REL:-}" ]]; then
  install_deb "$SCRIPT_DIR/$SATDUMP_DEB_REL"
else
  warn "No satdump*.deb found next to the script; skipping SatDump."
fi

log "Looking for local SDR++ .deb (sdrpp*.deb)…"
SDRPP_DEB_REL="$(choose_deb 'sdrpp*.deb' || true)"
if [[ -n "${SDRPP_DEB_REL:-}" ]]; then
  install_deb "$SCRIPT_DIR/$SDRPP_DEB_REL"
else
  warn "No sdrpp*.deb found next to the script; skipping SDR++."
fi

# ---------- done ----------
log "Done!"

echo -e "\nNext steps:"
echo "• Reboot recommended to finalize I²C and driver blacklist: sudo reboot"
echo "• Test I²C:             sudo i2cdetect -y 1"
echo "• Test RTL-SDR (V4):    rtl_test -p   (then Ctrl+C)"
echo "• Launch SatDump/SDR++ if installed by .deb (menu or command)."
