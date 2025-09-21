#!/usr/bin/env python3
# file: rot_i2c_bridge.py
import asyncio, math, time
from typing import Tuple

# --- I2C hardware layer (PCA9685 example) -----------------------
USE_PCA9685 = True
if USE_PCA9685:
    from adafruit_pca9685 import PCA9685
    import board, busio
    i2c = busio.I2C(board.SCL, board.SDA)
    pca = PCA9685(i2c)
    pca.frequency = 50  # typical for hobby servos

# Servo config (adjust to your mechanics)
AZ_CH = 0
EL_CH = 1
AZ_MIN_DEG, AZ_MAX_DEG = 0.0, 360.0   # wrap allowed; we’ll clamp output mapping to your mechanics
EL_MIN_DEG, EL_MAX_DEG = 0.0, 90.0

# If your servo is only 0–180, set these to your usable range and mechanically gear for 360 azimuth.
SERVO_MIN_US = 500     # microseconds pulse ~0°
SERVO_MAX_US = 2500    # microseconds pulse ~180°
SERVO_RANGE_DEG = 180  # typical hobby servo travel

def us_to_12bit_duty(us: float, freq=50) -> int:
    # PCA9685: 12-bit (0..4095). Period at 50 Hz is 20,000 us.
    period_us = 1_000_000 / freq
    duty = int((us / period_us) * 4096)
    return max(0, min(4095, duty))

def deg_to_us(deg: float) -> float:
    # Map 0..SERVO_RANGE_DEG → SERVO_MIN_US..SERVO_MAX_US
    d = max(0.0, min(SERVO_RANGE_DEG, deg))
    return SERVO_MIN_US + (SERVO_MAX_US - SERVO_MIN_US) * (d / SERVO_RANGE_DEG)

def servo_write(channel: int, deg: float):
    if not USE_PCA9685:
        return
    pulse_us = deg_to_us(deg)
    pca.channels[channel].duty_cycle = us_to_12bit_duty(pulse_us, pca.frequency)

# --- Simple kinematics / mapping -------------------------------
# Store current pos for reporting
current_az = 0.0
current_el = 0.0

# If your azimuth can do 0–360° continuously, you may want to choose shortest-path moves or absolute gearing.
# For hobby pan base, often 0–180° only; clamp and/or gear accordingly.
AZ_OUTPUT_MIN, AZ_OUTPUT_MAX = 0.0, 180.0  # servo limits
EL_OUTPUT_MIN, EL_OUTPUT_MAX = 0.0, 180.0

def map_az_el_to_outputs(az_deg: float, el_deg: float) -> Tuple[float,float]:
    # Clamp logical ranges
    az = max(AZ_MIN_DEG, min(AZ_MAX_DEG, az_deg))
    el = max(EL_MIN_DEG, min(EL_MAX_DEG, el_deg))
    # If your hardware only swings 0–180, compress az into 0–180 (use gearing or accept limited coverage)
    az_out = (az % 360.0) / 360.0 * (AZ_OUTPUT_MAX - AZ_OUTPUT_MIN) + AZ_OUTPUT_MIN
    el_out = (el - EL_MIN_DEG) / (EL_MAX_DEG - EL_MIN_DEG) * (EL_OUTPUT_MAX - EL_OUTPUT_MIN) + EL_OUTPUT_MIN
    return az_out, el_out

# Optional: simple rate limit to avoid snapping the servos
MAX_DEG_PER_STEP = 5.0

def slew_to(az_target: float, el_target: float):
    global current_az, current_el
    az_out, el_out = map_az_el_to_outputs(az_target, el_target)

    # Step in small increments
    steps = max(
        1,
        int(max(abs(az_out - current_az), abs(el_out - current_el)) / MAX_DEG_PER_STEP)
    )
    for i in range(1, steps + 1):
        iaz = current_az + (az_out - current_az) * i / steps
        iel = current_el + (el_out - current_el) * i / steps
        servo_write(AZ_CH, iaz)
        servo_write(EL_CH, iel)
        time.sleep(0.02)  # 50 Hz-ish update

    current_az, current_el = az_out, el_out

# --- Tiny rotctld-like server ----------------------------------
HELP = b"rot_i2c_bridge: commands: p (get), P az el (set), S (stop), q (quit)\n"

async def handle_client(reader: asyncio.StreamReader, writer: asyncio.StreamWriter):
    addr = writer.get_extra_info('peername')
    writer.write(HELP)
    await writer.drain()
    while True:
        data = await reader.readline()
        if not data:
            break
        line = data.decode(errors='ignore').strip()
        if not line:
            continue
        cmd = line.split()
        c0 = cmd[0].lower()

        if c0 == 'p' and len(cmd) == 1:
            # get position
            # Return the Hamlib style two-line response:
            writer.write(f"Azimuth: {current_az:.1f}\n".encode())
            writer.write(f"Elevation: {current_el:.1f}\n".encode())
            await writer.drain()

        elif c0 == 'p' and len(cmd) == 3:
            # Some clients send 'P az el' uppercase; accept lowercase too
            try:
                az = float(cmd[1]); el = float(cmd[2])
                slew_to(az, el)
                writer.write(b"RPRT 0\n")
                await writer.drain()
            except:
                writer.write(b"RPRT -1\n")
                await writer.drain()

        elif c0 == 'P' and len(cmd) == 3:
            # uppercase variant
            try:
                az = float(cmd[1]); el = float(cmd[2])
                slew_to(az, el)
                writer.write(b"RPRT 0\n")
                await writer.drain()
            except:
                writer.write(b"RPRT -1\n")
                await writer.drain()

        elif c0 == 's':
            # stop: implement if you have motion you can abort
            writer.write(b"RPRT 0\n")
            await writer.drain()

        elif c0 in ('q', 'quit', 'exit'):
            break

        elif c0 in ('help', '?'):
            writer.write(HELP)
            await writer.drain()

        else:
            # Unknown; be polite but terse
            writer.write(b"RPRT -8\n")  # command not supported
            await writer.drain()

    writer.close()
    await writer.wait_closed()

async def main():
    server = await asyncio.start_server(handle_client, host='0.0.0.0', port=4533)
    addrs = ", ".join(str(s.getsockname()) for s in server.sockets)
    print(f"Listening on {addrs} (rotctl net)")
    async with server:
        await server.serve_forever()

if __name__ == "__main__":
    asyncio.run(main())
