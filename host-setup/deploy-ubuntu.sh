#!/usr/bin/env sh
# Set to terminate script immediately if any command returns non-zero
set -e
SCRIPT_DIR=$( dirname -- "$( readlink -f -- "$0"; )"; )
cd "${SCRIPT_DIR}"
cd ..
export TARGET_HOST=$1
export BASE_OS=ubuntu

DWSETUP_GIT_DIR=wimsey-k8s-deploy

ssh-copy-id ${TARGET_HOST}
ssh ${TARGET_HOST} mkdir ${DWSETUP_GIT_DIR} || true
scp -rp * ${TARGET_HOST}:${DWSETUP_GIT_DIR}
echo Running host setup script - Privilege escalation on target host required
ssh -t ${TARGET_HOST} sudo ${DWSETUP_GIT_DIR}/host-setup/${BASE_OS}.sh

echo ''
echo ''
echo ==============================================================================
echo "To continue - for the intial microk8s node run the following, ssh $TARGET_HOST"
echo ./wimsey-k8s-deploy/setup-microk8s-main.sh
echo ''
echo 'If you have already completed the initial deploy and are deploying workers or control plane nodes'
echo Use
echo './wimsey-k8s-/deploy/setup-microk8s-worker <hostname>'
echo or
echo './wimsey-k8s-/deploy/setup-microk8s-controlplane <hostname>'
echo Respectively
echo ''
