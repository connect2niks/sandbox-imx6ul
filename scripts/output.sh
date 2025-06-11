#!/bin/bash

set -e

# Define source base directory
BASE_DIR=~/Documents/IoT_Sandbox_EOS/EOS_source/imx6ul
KERNEL_DIR=$BASE_DIR/kernel/linux-imx
BOOTLOADER_DIR=$BASE_DIR/bootloader/u-boot
OUTPUT_DIR=$BASE_DIR/outputs
BOOT_TXT=$OUTPUT_DIR/boot.txt
BOOT_SCR=$OUTPUT_DIR/boot.scr
CONFIGS_DIR=$BASE_DIR/configs


echo "========================================"
echo "        Custom EOS Build Script         "
echo "========================================"


echo "Copying uImage to outputs/"
sudo cp "$KERNEL_DIR/arch/arm/boot/uImage" "$OUTPUT_DIR/"

echo "Copying DTB (imx6ul-14x14-evk.dtb) to outputs/"
sudo cp "$KERNEL_DIR/arch/arm/boot/dts/nxp/imx/imx6ul-14x14-evk.dtb" "$OUTPUT_DIR/"

echo "Copying U-Boot image to outputs/"
sudo cp "$BOOTLOADER_DIR/u-boot-with-spl.imx" "$OUTPUT_DIR/"


######################### configs #####################################

echo "Copying kernel defconfig..."
cp "$KERNEL_DIR/arch/arm/configs/imx_v6_v7_defconfig" "$CONFIGS_DIR"

echo "Copying U-Boot defconfig..."
cp "$BOOTLOADER_DIR/configs/mx6ul_14x14_evk_defconfig" "$CONFIGS_DIR"

# Ensure mkimage is available
if ! command -v mkimage &> /dev/null; then
    echo "Error: mkimage not found. Please install U-Boot tools (e.g., u-boot-tools package)."
    exit 1
fi

echo "mkimage found."
echo "Generating boot.scr from boot.txt using mkimage"
mkimage -A arm -T script -C none -n "Boot Script" -d "$BOOT_TXT" "$BOOT_SCR"

echo "All output files copied successfully!"

