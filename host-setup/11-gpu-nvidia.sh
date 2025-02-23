#!/usr/bin/env sh
# Set to terminate script immediately if any command returns non-zero
set -e

#/mnt/software/GPU/nvidia/latest-x86_64-driver.run -m=kernel-open
/mnt/software/GPU/nvidia/latest-x86_64-cuda.run

nvidia-smi