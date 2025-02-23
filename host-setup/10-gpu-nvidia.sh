#!/usr/bin/env sh
# Set to terminate script immediately if any command returns non-zero
set -e

# Blacklist the nouveau driver, it gets in our way
touch /etc/modprobe.d/blacklist-nvidia-nouveau.conf
cat >> /etc/modprobe.d/blacklist-nvidia-nouveau.conf << EOF
blacklist nouveau
options nouveau modeset=0
EOF

# Enable Support for Unsupported GPUs (Consumer GPUs like the RTX3060
touch /etc/modprobe.d/nvidia.conf
cat >> /etc/modprobe.d/nvidia.conf << EOF
options nvidia NVreg_OpenRmEnableUnsupportedGpus=1
EOF

update-initramfs -u

apt install axel build-essential pkg-config libglvnd-dev -y
sudo reboot
