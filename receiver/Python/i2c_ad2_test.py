#!/usr/bin/env python3
import argparse, random, time
from smbus2 import SMBus, i2c_msg
import RPi.GPIO as GPIO

# ---------------- Helpers ----------------
def clamp16(x:int)->int: return max(0, min(0xFFFF, int(x)))

def pack_u32_be(h16:int, v16:int)->bytes:
    h16, v16 = clamp16(h16), clamp16(v16)
    word = (h16 << 16) | v16
    return word.to_bytes(4, "big", signed=False)  # [H_hi, H_lo, V_hi, V_lo]

def i2c_write_4(bus:SMBus, addr:int, data:bytes):
    assert len(data) == 4
    msg = i2c_msg.write(addr, data)
    bus.i2c_rdwr(msg)

# ------------- Tests (for AD2 capture) -------------
def test1_known_vectors(bus, addr, mark_pin):
    """
    Test 1: Deterministic “scope-friendly” vectors.
    Verify exact four bytes per transaction in WaveForms’ I2C decoder.
    """
    print("\n[TEST 1] Known vectors (edge cases & patterns)")
    vectors = [
        (0x0000, 0x0000),
        (0xFFFF, 0xFFFF),
        (0x1234, 0xABCD),
        (0xABCD, 0x1234),
        (0x00FF, 0xFF00),
        (0xAAAA, 0x5555),
        (0x8001, 0x7FFE),
    ]
    for (h, v) in vectors:
        payload = pack_u32_be(h, v)
        print(f"  H=0x{h:04X} V=0x{v:04X}  ->  {payload.hex(' ')}")
        # Marker high -> small settle -> write -> marker low
        GPIO.output(mark_pin, GPIO.HIGH); time.sleep(5e-6)
        i2c_write_4(bus, addr, payload)
        GPIO.output(mark_pin, GPIO.LOW)
        time.sleep(0.02)  # spacing for easy viewing

def test2_walking_ones(bus, addr, mark_pin):
    """
    Test 2: Walking-one across H then V.
    Lets you watch each bit position appear on the wire.
    """
    print("\n[TEST 2] Walking-one pattern")
    # H walking-one with V=0
    for bit in range(16):
        h, v = (1 << bit), 0
        payload = pack_u32_be(h, v)
        print(f"  H=1<<{bit:02d} V=0x0000 -> {payload.hex(' ')}")
        GPIO.output(mark_pin, GPIO.HIGH); time.sleep(5e-6)
        i2c_write_4(bus, addr, payload)
        GPIO.output(mark_pin, GPIO.LOW)
        time.sleep(0.008)
    # V walking-one with H=0
    for bit in range(16):
        h, v = 0, (1 << bit)
        payload = pack_u32_be(h, v)
        print(f"  H=0x0000 V=1<<{bit:02d} -> {payload.hex(' ')}")
        GPIO.output(mark_pin, GPIO.HIGH); time.sleep(5e-6)
        i2c_write_4(bus, addr, payload)
        GPIO.output(mark_pin, GPIO.LOW)
        time.sleep(0.008)

def test3_random_burst(bus, addr, mark_pin, n=50, interval=0.005):
    """
    Test 3: Randomized stress burst.
    Good for checking sustained correctness and timing at your chosen bus speed.
    """
    print("\n[TEST 3] Random burst")
    for i in range(n):
        h = random.randint(0, 0xFFFF)
        v = random.randint(0, 0xFFFF)
        payload = pack_u32_be(h, v)
        print(f"  [{i:02d}] H=0x{h:04X} V=0x{v:04X} -> {payload.hex(' ')}")
        GPIO.output(mark_pin, GPIO.HIGH); time.sleep(2e-6)
        i2c_write_4(bus, addr, payload)
        GPIO.output(mark_pin, GPIO.LOW)
        time.sleep(interval)

# ---------------- Main ----------------
def main():
    ap = argparse.ArgumentParser(description="I2C 32-bit (H|V) sender with AD2 marker")
    ap.add_argument("--bus", type=int, default=1, help="I2C bus number (default 1)")
    ap.add_argument("--addr", type=lambda x:int(x,0), required=True, help="Receiver I2C address, e.g. 0x20")
    ap.add_argument("--marker_gpio", type=int, default=18, help="GPIO for scope marker (BCM numbering). Default 18")
    ap.add_argument("--skip1", action="store_true", help="Skip Test 1")
    ap.add_argument("--skip2", action="store_true", help="Skip Test 2")
    ap.add_argument("--skip3", action="store_true", help="Skip Test 3")
    ap.add_argument("--n", type=int, default=50, help="Frames in Test 3")
    ap.add_argument("--interval", type=float, default=0.005, help="Seconds between frames in Test 3")
    args = ap.parse_args()

    # GPIO setup
    GPIO.setmode(GPIO.BCM)
    GPIO.setup(args.marker_gpio, GPIO.OUT, initial=GPIO.LOW)

    try:
        with SMBus(args.bus) as bus:
            if not args.skip1: test1_known_vectors(bus, args.addr, args.marker_gpio)
            if not args.skip2: test2_walking_ones(bus, args.addr, args.marker_gpio)
            if not args.skip3: test3_random_burst(bus, args.addr, args.marker_gpio, args.n, args.interval)
    finally:
        GPIO.output(args.marker_gpio, GPIO.LOW)
        GPIO.cleanup()

if __name__ == "__main__":
    main()
