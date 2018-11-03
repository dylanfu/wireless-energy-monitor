# Wireless Energy Monitor

## Description

In this project, we designed and implemented a wireless energy monitor to measure the voltage, current and power supplied to a load, for example a household appliance, and wirelessly transmit this data to a base station to be displayed.

The wireless energy monitor consists of two subsystems, a signal measurement unit and a base station, which communicates with each other wirelessly through Bluetooth.

Signal measurement unit consists of:
1. A sensing circuit to measure the load voltage and current.
2. A signal conditioning circuit to amplify and filter the sensed voltage and current.
3. A software-based digital processing system, which uses an ATmega328P microcontroller, to convert the analogue signals provided by the signal conditioning circuit to digital form and calculate the load voltage, current, power, power factor, etc. to be sent to a Bluetooth module connected to the microcontroller using serial bus (UART).
4. A Bluetooth module to transmit the information to the base station wirelessly.
5. A 5 V DC supply to provide power to the analogue and digital circuitry employed in the signal measurement unit.

Base station consists of:
1. A Bluetooth module to receive information transmitted by the measurement unit.
2. A 4-digit seven-segment display panel.
3. A CPLD based digital controller to receive the information, decode them and drive the display panel to show the information transmitted by the measurement unit.

## File Structure

The project files have been split into:
* Embedded C Design - Microcontroller code for signal processing
* VHDL Design - FPGA code for displaying measurements
* PCB Design - Altium schematics for the signal measurement circuit 
