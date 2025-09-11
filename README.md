# Mobile Antenna Tracking System (MATS)

![MATS Logo](/docs/images/logo.png)

## Overview
MATS (Mobile Antenna Tracking System) is a portable ground station platform designed to automatically track and recieve data from Low Earth Orbit (LEO) weather satellites. The system integrates: 
- Reciever Subsystem - Raspberry Pi 5 with SDR Hardware, SatDump, SDR++, and GPS timing. 
- Rotator Subsystem - Motorized antenna rotator with gearing and fixture assembly for precise azimuth/elevation pointing. 
- User Interface (UI) - Touchscreen controls, pass scheduling via Gpredict, and system health/status indicators. 
- Power Subsystem - Regulated DC rails providing reliable power to the Pi, motors, and peripherals. 

## Features 
- Automated Satellite pass prediction and antenna tracking.
- Real-time SDR signal aquisition and decoding via SatDump.
- Portable Architecture for field deployments 
- Open, Modular Design for extensibility. 
## Installation and Setup 
1. Receiver Subsystem 
    - Flash Raspberry Pi OS on a Pi 5. 
    - Run the provided install script to set up SatDump, SDR++, Gpredict, and required libraries. 
    ```bash 
    cd Receiver
    ./install.sh

2. Rotator Subsystem
    - Assemble Mechanical fixture (CAD models in [placeholder]). 
    - Flash motor control firmware to microcontroller. 
3. UI Subsystem 
    - Connect Pi Touchscreen 
    - Run UI code to access controls and system status. 

## Usage
- Use **Gpredict** to select a satellite pass. 
- The **Rotator** will align the antenna in real time. 
- SatDump automatically records and decodes the downlink. 
- Results are stored in `/Receiver/Data/` and can be reviewed via the UI.

## License
This project is licensed under the GNU General Public License V3.0 (GPL-3.0). You may redistribute and modify it nder the terms of the GPL as published by the Free Software Foundation. 

## Acknowledgements & External Software 
MATS leverages several excelled open-source projects: 
- [SatDump](https://github.com/SatDump/SatDump_) - Satellite signal demodulation and decoding. (Licensed under GPL-3.0)
- [SDR++](https://github.com/AlexandreRouma/SDRPlusPlus) - Software-defined radio receiver. (Licensed under GPL-3.0)
- [Gpredict](https://github.com/csete/gpredict) - Real-time satellite tracking and orbit protection. (Licensed under GPL-2.0)
- [VOLK](https://github.com/gnuradio/volk_) - Vector-optimized library of Kernels used by GNU Radio. (Licensed under GPL-3.0)
We extend sincere thanks to these communities for providing the tools that make this project possible. 