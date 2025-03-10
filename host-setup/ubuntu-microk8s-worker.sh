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

snap install --classic microk8s

sleep 5

microk8s status --wait-ready

microk8s join --worker --skip-verify $1
