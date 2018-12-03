#!/usr/bin/env bash

# This is an adapted version of the script found at https://gist.github.com/alexellis/a7b6c8499d9e598a285669596e9cdfa2

set -euxo pipefail
IFS=$'\n\t'

cd "$(dirname "$0")"

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root"
   exit 1
fi

echo "Writing Raspian image for host $RPI_HOSTNAME - 192.168.1.$RPI_IP_PART_4 to $RPI_SD_CARD_DEVICE with keys $RPI_AUTHORISED_SSH_KEYS"

curl -L https://downloads.raspberrypi.org/raspbian_lite_latest > raspian_lite.zip
unzip raspian_lite.zip
rm raspian_lite.zip
mv ./*.img ./raspian_lite.img

dd if=raspian_lite.img of=/dev/$RPI_SD_CARD_DEVICE bs=1M

sync

mount /dev/${RPI_SD_CARD_DEVICE}1 /mnt/rpi/boot
mount /dev/${RPI_SD_CARD_DEVICE}2 /mnt/rpi/root

mkdir -p /mnt/rpi/root/home/pi/.ssh/
echo "$RPI_AUTHORISED_SSH_KEYS" > /mnt/rpi/root/home/pi/.ssh/authorized_keys

touch /mnt/rpi/boot/ssh

sed -ie s/#PasswordAuthentication\ yes/PasswordAuthentication\ no/g /mnt/rpi/root/etc/ssh/sshd_config

echo "Setting hostname: $1"

sed -ie s/raspberrypi/$1/g /mnt/rpi/root/etc/hostname
sed -ie s/raspberrypi/$1/g /mnt/rpi/root/etc/hosts

# Reduce GPU memory to minimum
echo "gpu_mem=16" >> /mnt/rpi/boot/config.txt

cp /mnt/rpi/root/etc/dhcpcd.conf /mnt/rpi/root/etc/dhcpcd.conf.orig

sed s/100/$2/g template-dhcpcd.conf > /mnt/rpi/root/etc/dhcpcd.conf

echo "Unmounting SD Card"

umount /mnt/rpi/boot
umount /mnt/rpi/root

sync
