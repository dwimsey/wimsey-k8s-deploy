#!/usr/bin/env bash

source ./scripts/lib/common.sh

# Trap errors and call abort function if they occur
trap 'abort' 0
# Set to terminate script immediately if any command returns non-zero, the initial microk8s commands may return an error even when successful so we wait til now to enable it
set -e



if [ ! -f ~/.bash_aliases ]; then
  # Copy aliases to make life easier in the future, this provides the `kubectl` and `oc` aliases via the microk8s command
  cp ./bin/bash_aliases ~/.bash_aliases
  source ~/.bash_aliases
fi

if [ -z "$INSTALLER_USER" ]; then
cat << EOFA

This script will install MicroK8S and configure it for development with some basic services missing from vanilla MicroK8S.

Press any key to continue, Control-C to abort.
EOFA

# Wait for a key press
read -n 1

fi

# The remaining bits of this script require root/superuser, are we the super user?
if [ "$EUID" -ne 0 ]; then
  # We are not currently running as the super user, recall ourselves using sudo
  # We set INSTALLER_USER to our username so that this script can add the user to the microk8s group later
  echo This script must be executed as the super user, using sudo to run as super user ...
  # Use exec to call ourselves via sudo, so sudo assumes this process space and this script ceases to execute
  exec sudo HOST=$HOST INSTALLER_USER=$USER $0 $@

  echo SHOULD NEVER GET HERE!
  exit
fi

# Install MicroK8S using snap (This assumes we're running in Ubuntu 20.04 LTS
snap install microk8s --classic

# If INSTALLER_USER is set, we need to add the specified user to the microk8s group to allow running microk8s command
# without sudo.  INSTALLER_USER is empty, then don't do anything
if [ ! -z "$INSTALLER_USER" ]; then
  sudo usermod -a -G microk8s $INSTALLER_USER
  sudo chown -f -R $INSTALLER_USER ~/.kube
fi

 Install NFS common package as we'll need it to mount NFS shares for pods to have storage
 apt-get install -y nfs-common

# Wait for microk8s to get started and become ready
microk8s status --wait-ready

# Install the rbac, dns and dashboard plugins
microk8s enable rbac dns dashboard


# Retrieve the admin token
#AUTH_TOKEN=$(microk8s config | grep token | cut -f2 -d':' | cut -f2 -d' ')
AUTH_TOKEN=$(oc.exe whoami -t)

# Do we need to create a wrapper script for 'microk8s kubectl' so kubectl-use is happy?
if [ ! -f "/usr/local/bin/kubectl" ]; then
  # Create wrapper in /usr/local/bin/kubectl
  echo '#!/usr/bin/env bash' > /usr/local/bin/kubectl
  echo 'exec microk8s kubectl $@' >> /usr/local/bin/kubectl
  chown root: /usr/local/bin/kubectl
  chmod 0755 /usr/local/bin/kubectl
fi

# Create initial basic namespaces for installing 3rd party components considered essential
process_resource_directory resources/00_namespaces
process_resource_directory resources/00_secrets

# Create critical services: ingress router, storage, ect and wait for them to start
process_resource_directory resources/01_bootstrap
echo -n "Waiting for nfs storage provider pod to start"
wait_for_pod kube-storage k8s-app=nfs-client-provisioner 600
echo -n "Waiting for ingress router pod to start"
wait_for_pod openshift-ingress k8s-app=ingress-router 600

# Create the dashboard route and then wait the dashboard and route to become available
process_resource_directory resources/10_baseservices
echo -n "Waiting for dashboard pod to start"
wait_for_pod kube-system k8s-app=kubernetes-dashboard 600

echo -n "Waiting for base routes to become available: "
echo -n " API"
while [[ $(microk8s kubectl get route -n default kubernetes-api -o 'jsonpath={..status.ingress[*].conditions[?(@.type=="Admitted")].status}') != "True" ]]; do echo -n . && sleep 1; done
echo -n " Dashboard"
while [[ $(microk8s kubectl get route -n kube-system kubernetes-dashboard -o 'jsonpath={..status.ingress[*].conditions[?(@.type=="Admitted")].status}') != "True" ]]; do echo -n . && sleep 1; done
echo

process_resource_directory resources/50_general
echo -n "Waiting for authentication system (vault pod) to start"
wait_for_pod vault k8s-app=vault 600

echo -n "Waiting for murmur server to start"
wait_for_pod murmur app=murmur 600


# Notify the user we're done and provide some basic instructions
cat << EOF

===============================================================================
Done!
===============================================================================


If this is the first time executing this script, you may need to logout and log back in again for all groups and
aliases to take effect.

===============================================================================
Web Dashboard
===============================================================================

To login to the dashboard visit https://$HOST in your browser and login using the following administrator token:

$AUTH_TOKEN

===============================================================================
Remote oc
===============================================================================

If you have installed the 'oc' binary from an OpenShift distribution, the following command will login to this server:

oc login https://k8s-api.wimsey.us --token=$AUTH_TOKEN

===============================================================================
Remote kubectl
===============================================================================

If you wish to access this system using the oc or kubectl commands remotely, you can export this kubeconfig file using
the following command:

ssh $INSTALL_USER@pi-01.wimsey.us microk8s config > ~/.kube/config
kubectl config set-cluster microk8s-cluster --server=https:///k8s-api.wimsey.us


You may now run commands such as:
kubectl get pods --all-namespaces

Enjoy!

EOF

trap : 0
