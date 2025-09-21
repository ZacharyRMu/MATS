#!/usr/bin/env python3
"""
LED Test Script for Raspberry Pi (Receiver Subsystem UI)

- Power LED is hardware-tied to 5V, no software control.
- GPS Lock LED    -> GPIO17 (pin 11)
- RF Active LED   -> GPIO27 (pin 13)
- Error/Fault LED -> GPIO22 (pin 15)

This script blinks each LED in sequence, then cycles, then all together.
"""

import time
from gpiozero import LED

# Define LEDs
gps_led   = LED(17)  # GPS Lock
rf_led    = LED(27)  # RF Active
error_led = LED(22)  # Error/Fault

leds = [gps_led, rf_led, error_led]

def blink_led(led, name, count=3, delay=0.5):
    """Blink one LED a given number of times"""
    print(f"Testing {name} LED...")
    for _ in range(count):
        led.on()
        time.sleep(delay)
        led.off()
        time.sleep(delay)

def chase_pattern(cycles=3, delay=0.2):
    """Cycle LEDs in a 'chase' pattern"""
    print("Running chase pattern...")
    for _ in range(cycles):
        for led in leds:
            led.on()
            time.sleep(delay)
            led.off()

def all_blink(count=3, delay=0.5):
    """Blink all LEDs together"""
    print("Blinking all LEDs together...")
    for _ in range(count):
        for led in leds:
            led.on()
        time.sleep(delay)
        for led in leds:
            led.off()
        time.sleep(delay)

if __name__ == "__main__":
    try:
        # Individual tests
        blink_led(gps_led, "GPS Lock")
        blink_led(rf_led, "RF Active")
        blink_led(error_led, "Error/Fault")

        # Patterns
        chase_pattern()
        all_blink()

        print("LED test complete.")

    except KeyboardInterrupt:
        print("\nTest interrupted.")
    finally:
        # Ensure all LEDs are off on exit
        for led in leds:
            led.off()
