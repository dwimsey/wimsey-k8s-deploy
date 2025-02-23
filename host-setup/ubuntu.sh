#!/usr/bin/env bash

# Set to terminate script immediately if any command returns non-zero
set -e

if [ "$EUID" -ne 0 ]; then
  # We are not currently running as the super user, recall ourselves using sudo
  # We set INSTALLER_USER to our username so that this script can add the user to the microk8s group later
  echo This script must be executed as the super user, using sudo to run as super user ...
  # Use exec to call ourselves via sudo, so sudo assumes this process space and this script ceases to execute
  exec sudo INSTALLER_USER=$USER bash $0 $@

  echo SHOULD NEVER GET HERE!
  exit
fi

SCRIPT_DIR=$( dirname -- "$( readlink -f -- "$0"; )"; )

cd $SCRIPT_DIR

sh ./fix_sudoers.sh

apt update
apt upgrade -y
apt install -y nano git nethogs htop iotop nfs-common net-tools open-vm-tools

mkdir -p /mnt/software
echo '' >> /etc/fstab
echo '# Mount shared software archive over nfs' >> /etc/fstab
echo 'vmnas01:/mnt/pool0/software /mnt/software nfs ro 0 0' >> /etc/fstab

systemctl daemon-reload
mount -a

reboot
