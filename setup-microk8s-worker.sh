#!/usr/bin/env sh
# Set to terminate script immediately if any command returns non-zero
set -e
SCRIPT_DIR=$( dirname -- "$( readlink -f -- "$0"; )"; )
cd "${SCRIPT_DIR}"

export TARGET_HOST=$1
export BASE_OS=ubuntu

DWSETUP_GIT_DIR=wimsey-k8s-deploy

# ensure the remote node has the current setup directory
scp -rp * ${TARGET_HOST}:${DWSETUP_GIT_DIR}

# Get the join secret/host
K8S_CLUSTER_JOIN_INFO=$(ssh -t k8s-cp-00.wimsey.us sudo microk8s add-node | cut -f3 -d' ' | grep '192.168' | head -n 1)

# Run the join script for workers
ssh -t ${TARGET_HOST} sudo ${DWSETUP_GIT_DIR}/host-setup/${BASE_OS}-microk8s-worker.sh $K8S_CLUSTER_JOIN_INFO
