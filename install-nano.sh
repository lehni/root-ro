#!/bin/sh

# Error out if anything fails.
set -e

# Make sure script is run as root.
if [ "$(id -u)" != "0" ]; then
  echo "Must be run as root with sudo! Try: sudo ./install-nano.sh"
  exit 1
fi

if dpkg --get-selections | grep -q "^dphys-swapfle\s*install$" >/dev/null; then
    echo Disabling swap, we dont want swap files in a read-only root filesystem...
    dphys-swapfile swapoff
    dphys-swapfile uninstall
    update-rc.d dphys-swapfile disable
    systemctl disable dphys-swapfile
else
    echo dphys-swapfile is not installed, assuming we dont need to disable swap
fi

echo Setting up maintenance scripts in /root...
cp root/* /root/
chmod +x /root/reboot-ro
chmod +x /root/reboot-rw
chmod +x /root/mount-ro
chmod +x /root/mount-rw

echo Setting up initramfs-tools scripts...
cp etc/initramfs-tools/scripts/init-bottom/root-ro /etc/initramfs-tools/scripts/init-bottom/root-ro
cp etc/initramfs-tools/hooks/root-ro /etc/initramfs-tools/hooks/root-ro
chmod +x /etc/initramfs-tools/scripts/init-bottom/root-ro
chmod +x /etc/initramfs-tools/hooks/root-ro

if ! grep -q "^overlay" /etc/initramfs-tools/modules; then
  echo Adding \"overlay\" to /etc/initramfs-tools/modules
  echo overlay >> /etc/initramfs-tools/modules
fi

echo Updating initramfs...
update-initramfs -u

if ! grep -q "INITRD /boot/initrd.img" /boot/extlinux/extlinux.conf; then
  echo Changing INITRD in /boot/extlinux/extlinux.conf
  sed -i "s/INITRD \/boot\/initrd/INITRD \/boot\/initrd.img/" /boot/extlinux/extlinux.conf
fi

echo Removing the random seed file
systemctl stop systemd-random-seed.service
if [ -f /var/lib/systemd/random-seed ]; then
  rm -f /var/lib/systemd/random-seed
fi

# Restarting without warning seems a bit harsh, so we'll just inform that it's
# necessary reboot
echo Please restart your Jetson Nano now to boot into read-only mode
