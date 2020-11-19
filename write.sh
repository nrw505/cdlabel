#!/bin/sh

DEVICE="IOService:/AppleACPIPlatformExpert/PCI0/AppleACPIPCI/EHC1@1D,7/AppleUSBEHCI/USB to Serial-ATA bridge@fd100000/Bulk Only Interface@0/IOUSBMassStorageClass/IOSCSIPeripheralDeviceNub/IOSCSIPeripheralDeviceType05/IODVDServices"

diskutil unmount disk6
cdrdao write --device "$DEVICE" --driver generic-mmc-raw --eject --datafile data.bin data.toc && rm -f data.bin data.toc
