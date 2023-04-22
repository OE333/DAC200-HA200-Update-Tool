# DAC200-HA200-Update-Tool
Firmware update tool for T+A DAC200 and HA200 devices.

The tool is written in Pascal, using Lazarus IDE and is intended for use on a Windows PC.

For those only interested in upgrading the firmware of DAC200/HA200: a compiled version of this program can be found in the subfolder /executable.

To run this program a Windows PC with serial RS232 interface (COM port) is needed. A USB/RS232 converter can be used in cases where there is no COM port available on the PC.
Please read the instructions in the "related documents" folder for further information on the required hardware.

Keep in mind that re-flashing a microprocessor (that is what this program does) is never free of risk. 
If anything goes wrong (loss of power, loss of connection) this can possibly damage the device to be flashed. In worst case the device to be flashed could be bricked and will not work any more...

I believe that this program is sufficiently safe but I take no responsibility for any risks resulting from using this software.

History
2023/04/22: V 1.05 - initial version
