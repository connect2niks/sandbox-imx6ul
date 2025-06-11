#!/bin/bash

set -e

cd ~/Documents/IoT_Sandbox_EOS/EOS_source/imx6ul || exit 1

echo "Backing up kernel/linux-imx..."
tar -czf kernel/linux.tar.gz -C kernel linux-imx

echo "Backing up bootloader/u-boot..."
tar -cJf bootloader/u-boot.tar.xz -C bootloader u-boot

echo "Backing up rootfs/rootfs..."
sudo tar -czf rootfs/rootfs.tar.gz -C rootfs rootfs

echo "Backup complete."

