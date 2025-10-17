#!/usr/bin/env python3
"""
RTL-SDR activity → GPIO17.
Auto-detects the RTL2832U on USB and sets GPIO17 HIGH while the device file
is open by any process (SatDump, rtl_tcp, etc.).

Deps: sudo apt-get install python3-rpi.gpio python3-usb lsof
Run : sudo python3 rtl_activity_gpio17.py
"""

import time
import subprocess
import sys
from typing import Optional

# --- GPIO setup (works on Pi 4/5) ---
try:
    import RPi.GPIO as GPIO
except Exception as e:
    print("ERROR: RPi.GPIO not available. Install with: sudo apt-get install python3-rpi.gpio")
    raise

GPIO_PIN = 17
GPIO.setmode(GPIO.BCM)
GPIO.setup(GPIO_PIN, GPIO.OUT)
GPIO.output(GPIO_PIN, GPIO.LOW)

# --- USB discovery (pyusb) ---
try:
    import usb.core
    import usb.util
except Exception:
    print("ERROR: pyusb not available. Install with: sudo apt-get install python3-usb")
    GPIO.cleanup()
    sys.exit(1)

# Known Realtek RTL2832U VID/PIDs (common sticks)
RTL_VID = 0x0BDA
RTL_PIDS = {0x2832, 0x2838, 0x283F}  # include common variants

def find_rtl_device_path() -> Optional[str]:
    """
    Returns /dev/bus/usb/BBB/DDD for the first detected RTL-SDR, else None.
    """
    devs = []
    for d in usb.core.find(find_all=True, idVendor=RTL_VID):
        if d.idProduct in RTL_PIDS:
            devs.append(d)

    if not devs:
        return None

    # Prefer a device that reports a serial, else first
    devs.sort(key=lambda d: (0 if usb.util.get_string(d, d.iSerialNumber) else 1, d.bus, d.address))
    d = devs[0]
    # Map to Linux usbfs path
    bus = f"{getattr(d, 'bus', 0):03d}"
    addr = f"{getattr(d, 'address', 0):03d}"
    return f"/dev/bus/usb/{bus}/{addr}"

def path_in_use(path: str) -> bool:
    """
    True if any process has the device file open.
    Uses lsof; run this script with sudo for best results.
    """
    try:
        # -F p gives only PIDs (faster to parse); fall back to plain if not supported
        res = subprocess.run(["lsof", "-Fn", path], capture_output=True, text=True, timeout=2)
        out = (res.stdout or "") + (res.stderr or "")
        # lsof prints nothing when no handles; otherwise lines like "p1234"
        return any(line.startswith("p") for line in out.splitlines())
    except Exception:
        return False

def main():
    print("[rtl-gpio] Scanning for RTL-SDR…")
    dev_path = None

    # Try for a while in case the stick is hotplugged later
    for _ in range(20):
        dev_path = find_rtl_device_path()
        if dev_path:
            break
        time.sleep(0.5)

    if not dev_path:
        print("[rtl-gpio] No RTL-SDR found (VID 0x0BDA / PID 0x2832/0x2838/0x283F). "
              "Plug it in and rerun, or add your PID to RTL_PIDS.")
        GPIO.cleanup()
        sys.exit(2)

    print(f"[rtl-gpio] Monitoring {dev_path} for activity → GPIO17")
    try:
        last_state = None
        while True:
            active = path_in_use(dev_path)
            if active != last_state:
                GPIO.output(GPIO_PIN, GPIO.HIGH if active else GPIO.LOW)
                print(f"[rtl-gpio] {'ACTIVE' if active else 'IDLE'} → GPIO17 "
                      f"{'HIGH' if active else 'LOW'}")
                last_state = active
            time.sleep(0.5)
    except KeyboardInterrupt:
        pass
    finally:
        GPIO.output(GPIO_PIN, GPIO.LOW)
        GPIO.cleanup()

if __name__ == "__main__":
    main()
