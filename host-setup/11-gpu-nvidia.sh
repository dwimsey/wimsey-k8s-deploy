#!/usr/bin/env sh
# Set to terminate script immediately if any command returns non-zero
set -e

#/mnt/software/GPU/nvidia/latest-x86_64-driver.run -m=kernel-open
/mnt/software/GPU/nvidia/latest-x86_64-cuda.run --silent -m=kernel-open --no-drm

nvidia-smi

echo When ready run
echo ''
echo microk8s enable nvidia --gpu-operator-driver host --gpu-operator-set driver.enabled=false
echo
echo 'To enable the nVidia operator'
