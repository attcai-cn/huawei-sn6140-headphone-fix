#!/bin/sh
# Remove the firmware-patch workaround. Must be run as root. Reboot afterwards.
set -e

if [ "$(id -u)" -ne 0 ]; then
	echo "run as root" >&2
	exit 1
fi

rm -f /lib/firmware/hda-jack-retask.fw
rm -f /etc/modprobe.d/hda-jack-retask.conf
rm -f /etc/initramfs-tools/hooks/hda-jack-retask

update-initramfs -u

echo
echo "Removed. Reboot to restore the previous behaviour."
