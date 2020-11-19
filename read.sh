#!/bin/sh

# Find the first audio CD
DISK=$(disktool -l | grep "fsType = 'cddafs'" | head -n 1 | cut -f 2 -d \')

TITLE=$(disktool -l | grep "fsType = 'cddafs'" | head -n 1  | sed -e "s/.*volName = '//" | sed -e "s/')//")

DEVICE="IOService:/AppleACPIPlatformExpert/PCI0/AppleACPIPCI/PATA@1F,1/AppleIntelPIIXATARoot/PRID@0/AppleIntelPIIXPATA/ATADeviceNub@0/IOATAPIProtocolTransport/IOSCSIPeripheralDeviceNub/IOSCSIPeripheralDeviceType05/IODVDServices"

#DEVICE="IOService:/AppleACPIPlatformExpert/PCI0/AppleACPIPCI/EHC1@1D,7/AppleUSBEHCI/USB to Serial-ATA bridge@fd100000/Bulk Only Interface@0/IOUSBMassStorageClass/IOSCSIPeripheralDeviceNub/IOSCSIPeripheralDeviceType05/IODVDServices"

diskutil unmount $DISK
cdrdao read-cd --device "$DEVICE" --datafile data.bin --read-raw --paranoia-mode 3 --with-cddb --cddb-servers freedb.freedb.org:80:/~cddb/cddb.cgi data.toc
sleep 5
diskutil eject $DISK
