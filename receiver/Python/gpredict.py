#!/usr/bin/env python3
import asyncio
import struct
import time

import board
import busio

# --- Configuration -----------------------
ARDUINO_I2C_ADDR = 0x08  # Must match the Arduino sketch
I2C_BUS_FREQ = 100000    # 100 kHz

# Initialize I2C
i2c = busio.I2C(board.SCL, board.SDA, frequency=I2C_BUS_FREQ)

# Store current pos for reporting (Gpredict expects feedback)
current_az = 0.0
current_el = 0.0


def send_to_arduino(az: float, el: float):
    """
    Packs two floats (little-endian) and writes them to the Arduino.
    Protocol: [AZ_FLOAT][EL_FLOAT] (8 bytes total)
    """
    try:
        # locking is required for CircuitPython busio
        while not i2c.try_lock():
            time.sleep(0.001)  # avoid a tight spin

        # 'f' is a 4-byte float. '<' denotes little-endian (standard for Arduino AVR/ARM)
        payload = struct.pack('<ff', az, el)
        i2c.writeto(ARDUINO_I2C_ADDR, payload)

    except OSError as e:
        print(f"I2C Write Error: {e}")
    finally:
        try:
            i2c.unlock()
        except RuntimeError:
            # If unlock fails because it wasn't locked, just ignore
            pass


# --- Rotctld Server ----------------------------------
async def handle_client(reader: asyncio.StreamReader, writer: asyncio.StreamWriter):
    global current_az, current_el

    addr = writer.get_extra_info('peername')
    print(f"Client connected from {addr}")
    writer.write(b"rot_i2c_bridge ready\n")
    await writer.drain()

    while True:
        data = await reader.readline()
        if not data:
            break

        line = data.decode(errors='ignore').strip()
        if not line:
            continue

        print(f"RX: {line!r}")
        cmd = line.split()
        if not cmd:
            continue

        c0 = cmd[0].upper()  # normalize command for matching

        # SET POSITION: P <Az> <El>
        if c0 == 'P' and len(cmd) == 3:
            try:
                target_az = float(cmd[1])
                target_el = float(cmd[2])

                # Update global state
                current_az, current_el = target_az, target_el

                # Send to Arduino immediately
                send_to_arduino(current_az, current_el)

                writer.write(b"RPRT 0\n")
            except ValueError:
                writer.write(b"RPRT -1\n")
            await writer.drain()

        # GET POSITION: p (hamlib uses lowercase 'p', but we normalized to uppercase)
        elif c0 == 'P' and len(cmd) == 1:
            # Gpredict asks where we are.
            # Echoing last commanded position is fine for open-loop systems.
            response = f"{current_az:.1f}\n{current_el:.1f}\n"
            writer.write(response.encode())
            await writer.drain()

        # QUIT
        elif c0 == 'Q':
            break

        else:
            # Unknown or malformed command
            writer.write(b"RPRT -1\n")
            await writer.drain()

    print(f"Client disconnected from {addr}")
    writer.close()
    await writer.wait_closed()


async def main():
    server = await asyncio.start_server(handle_client, '0.0.0.0', 4533)
    print("Serving rotctld on 0.0.0.0:4533...")
    async with server:
        await server.serve_forever()


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        print("\nBridge stopped.")
