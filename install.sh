#!/bin/sh
# Install the firmware-patch workaround for the Huawei SN6140 headphone jack.
# Must be run as root. Reboot afterwards.
set -e

HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

if [ "$(id -u)" -ne 0 ]; then
	echo "run as root" >&2
	exit 1
fi

install -Dm644 "$HERE/hda-jack-retask.fw" /lib/firmware/hda-jack-retask.fw
install -Dm644 "$HERE/hda-jack-retask.conf" /etc/modprobe.d/hda-jack-retask.conf
install -Dm755 "$HERE/hda-jack-retask.initramfs-hook" /etc/initramfs-tools/hooks/hda-jack-retask

update-initramfs -u

echo
echo "Installed. Reboot to apply."
echo "After reboot, verify with:"
echo "  dmesg | grep hp_outs"
echo "  amixer -c0 controls | grep -i headphone"
echo "  pactl list sinks | grep -i headphone"
