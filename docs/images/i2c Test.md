# I²C Angle Output Test Procedure (Raspberry Pi + Analog Discovery)

This document describes how to verify that the Raspberry Pi outputs the correct 32-bit I²C word
`[H(16) | V(16)]` using the Analog Discovery logic analyzer.

---

## Overview
- **Data format**: `uint32 = (H << 16) | V`
  - First 16 bits = **Horizontal angle**
  - Second 16 bits = **Vertical angle**
  - Byte order: **Big-endian** → `[H_hi, H_lo, V_hi, V_lo]`

- **Verification method**: Use a Digilent Analog Discovery (AD2/AD3) with WaveForms to capture I²C traffic and confirm the 4 data bytes match the expected values.

---

## Hardware Setup
1. **Raspberry Pi**  
   - I²C enabled (`raspi-config → Interface Options → I2C`).
   - Script: [`i2c_ad2_test.py`](./i2c_ad2_test.py).

2. **Connections**  
   | AD2 Logic | Connect To |
   |-----------|------------|
   | Logic 0   | Pi SDA (GPIO2, pin 3) |
   | Logic 1   | Pi SCL (GPIO3, pin 5) |
   | Logic 2   | Pi GPIO18 (pin 12) → **Marker output** (optional) |
   | GND       | Pi GND (e.g., pin 6) |

   > Pi uses 3.3 V logic. Set AD2 logic threshold ≈ 1.5–2.0 V.

---

## Software Setup
Install dependencies:
```bash
sudo apt update
sudo apt install -y python3-smbus i2c-tools python3-rpi.gpio
```

Confirm the I²C device address: 
```bash
i2detect -y 1
```

## Running the Tests 
Run the script, providing your receiver's I²C address: 
```bash 
python3 i2c_ad2_test.py --addr 0x20
```
Available tests:

1. Known vectors (edge cases & patterns)

2. Walking-ones (bit-by-bit check across H and V)

3. Random burst (stress test with many frames)

Skip a test with `--skip1`, `--skip2`, or `--skip3`.

## Capturing with WaveForms: 
1. Open Logic Instrument 
2. Set:
    - Channels SDA = D0, SCL = D1, Marker = D2 (optional)
    - Protocol Decoder: I²C (Address + data view)
    - Sample Rate: 10MHz or greater 
    - Trigger: Rising edge on D2 (marker)
3. Run capture while the Pi sends data. 

## What to Look For
- Each I²C transaction should decode as: 
```css
Start → Address(0x20 W) → Data: XX XX XX XX → Stop
```
- Compare the **four data bytes** with the console printout: 
    - example: `H=0x1234 V=0xABCD` → `12 34 AB CD`
- Walking-ones test: A single bit should "walk," across H (first two bytes,) then V (last two.)

