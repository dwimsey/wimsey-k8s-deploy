#!/usr/bin/env bash
trap 'abort' 0
# Set to terminate script immediately if any command returns non-zero, the initial microk8s commands may return an error even when successful so we wait til now to enable it
set -e

abort() {
    echo >&2 '
***************
*** ABORTED ***
***************
'
    echo "An error occurred. Exiting . . ." >&2
    exit 1
}

K8S_CONTROL_NODE=$1
shift

if [ -z "$ADD_NODE_CMD" ]; then
  cat << EOF

This script will install MicroK8S and configure it function as a worker node in the cluster controlled by ${K8S_CONTROL_NODE}

Press any key to continue, Control-C to abort.
EOF

  # Wait for a key press
  read -n 1

  echo Gathering connection string from master node ${K8S_CONTROL_NODE}
  ADD_NODE_CMD=$(ssh -t $K8S_CONTROL_NODE sudo microk8s add-node --format short 2>/dev/null | head -n 1 | sed 's/[\r\n]//g')
fi

# The remaining bits of this script require root/superuser, are we the super user?
if [ "$EUID" -ne 0 ]; then
  # We are not currently running as the super user, recall ourselves using sudo
  # We set INSTALLER_USER to our username so that this script can add the user to the microk8s group later
  echo This remainder of this script must be executed as the super user, using sudo to run as super user ...
  # Use exec to call ourselves via sudo, so sudo assumes this process space and this script ceases to execute
  exec sudo ADD_NODE_CMD="$ADD_NODE_CMD" bash $0 $K8S_CONTROL_NODE $@

  echo SHOULD NEVER GET HERE!
  exit
fi

echo ''
echo "Add command: ${ADD_NODE_CMD}"


RELATIVE_SCRIPT_DIR=$( dirname -- "$( readlink -f -- "$0"; )"; )
SCRIPT_DIR=$(realpath ${RELATIVE_SCRIPT_DIR}/..)

echo "Script execution directory: ${SCRIPT_DIR}"
cd "${SCRIPT_DIR}"

source ./scripts/lib/common.sh


# Install MicroK8S using snap (This assumes we're running in Ubuntu 20.04 LTS
echo Installing microk8s
snap install microk8s --classic

echo Waiting 5 seconds for microk8s to stablize
sleep 5

echo Waiting for microk8s to confirm ready
microk8s status --wait-ready > /dev/null

echo Attempting to join cluster ...
echo $ADD_NODE_CMD --worker --skip-verify
$ADD_NODE_CMD --worker --skip-verify