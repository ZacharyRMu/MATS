#!/usr/bin/env bash
sudo raspi-config #interfacing options: I2C -> Enable
sudo apt-get update && sudo apt-get install -y python3-zip
pip3 install adafruit-circuitpython-pca9865