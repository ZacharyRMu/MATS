#!/usr/bin/env bash
set -euo pipefail

echo "=== SDR Stack Verification ==="

check_cmd() {
  local name="$1"
  local cmd="$2"
  local grep_pat="$3"

  echo -n "[*] Checking $name... "
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "FAIL (not found in PATH)"
    return 1
  fi
  if ! "$cmd" --version 2>&1 | grep -qi "$grep_pat"; then
    echo "FAIL (no expected version string)"
    return 1
  fi
  echo "PASS"
}

# 1. GPSD driver/service
echo -n "[*] Checking gpsd... "
if dpkg -l | grep -q gpsd && systemctl is-active --quiet gpsd; then
  echo "PASS"
else
  echo "FAIL (not installed or not running)"
fi

# 2. SatDump
check_cmd "SatDump" "satdump" "satdump" || true

# 3. Gpredict
check_cmd "Gpredict" "gpredict" "gpredict" || true

# 4. SDR++
check_cmd "SDR++" "sdrpp" "sdr" || true

echo "=== Verification complete ==="
