#!/usr/bin/env bash
set -euo pipefail

echo "=== SDR Stack Verification ==="

check_cmd() {
  local name="$1"
  local cmd="$2"
  shift 2
  local patterns=("$@")   # one or more strings to look for

  echo -n "[*] Checking $name... "
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "FAIL (not found in PATH)"
    return 0
  fi

  # Try a few common version switches without failing the script
  local out=""
  for flag in "--version" "-v" "-V"; do
    if out="$("$cmd" "$flag" 2>&1)" ; then
      # Found a working flag; validate expected patterns (if any)
      local ok=1
      for pat in "${patterns[@]}"; do
        if echo "$out" | grep -qi "$pat"; then ok=0; fi
      done
      if [[ $ok -eq 0 || ${#patterns[@]} -eq 0 ]]; then
        echo "PASS"
        return 0
      fi
    fi
  done

  # If version flags failed, at least confirm it runs/help
  if "$cmd" --help >/dev/null 2>&1 || "$cmd" -h >/dev/null 2>&1; then
    echo "PASS (no version output)"
  else
    echo "FAIL (no expected version/help)"
  fi
}

# 1) gpsd (package + active service or socket)
echo -n "[*] Checking gpsd... "
if dpkg -l gpsd 2>/dev/null | grep -q '^ii' && \
   (systemctl is-active --quiet gpsd || systemctl is-active --quiet gpsd.socket); then
  echo "PASS"
else
  echo "FAIL (not installed or not active)"
fi

# 2) SatDump
check_cmd "SatDump" "satdump" "satdump"

# 3) Gpredict
check_cmd "Gpredict" "gpredict" "gpredict"

# 4) SDR++
check_cmd "SDR++" "sdrpp" "sdr"

echo "=== Verification complete ==="