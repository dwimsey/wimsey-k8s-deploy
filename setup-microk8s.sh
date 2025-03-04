#!/usr/bin/env bash
# Trap errors and call abort function if they occur
trap 'abort' 0
# Set to terminate script immediately if any command returns non-zero, the initial microk8s commands may return an error even when successful so we wait til now to enable it
set -e

if [ -z "$INSTALLER_USER" ]; then
cat << EOF

This script will install MicroK8S and configure it for development with some basic services missing from vanilla MicroK8S.

Press any key to continue, Control-C to abort.
EOF

# Wait for a key press
read -n 1

fi

# The remaining bits of this script require root/superuser, are we the super user?
if [ "$EUID" -ne 0 ]; then
  # We are not currently running as the super user, recall ourselves using sudo
  # We set INSTALLER_USER to our username so that this script can add the user to the microk8s group later
  echo This script must be executed as the super user, using sudo to run as super user ...
  # Use exec to call ourselves via sudo, so sudo assumes this process space and this script ceases to execute
  exec sudo INSTALLER_USER=$USER bash $0 $@

  echo SHOULD NEVER GET HERE!
  exit
fi

RELATIVE_SCRIPT_DIR=$( dirname -- "$( readlink -f -- "$0"; )"; )
SCRIPT_DIR=$(realpath ${RELATIVE_SCRIPT_DIR})
USER_HOME=$(sudo -u "$INSTALLER_USER" sh -c 'echo $HOME')

echo "Script execution directory: ${RELATIVE_SCRIPT_DIR}"
cd "${SCRIPT_DIR}"

source ./scripts/lib/common.sh

# Install MicroK8S using snap (This assumes we're running in Ubuntu 20.04 LTS
echo Installing microk8s
snap install microk8s --classic

# If INSTALLER_USER is set, we need to add the specified user to the microk8s group to allow running microk8s command
# without sudo.  INSTALLER_USER is empty, then don't do anything
if [ ! -z "$INSTALLER_USER" ]; then
  echo Adding user to microk8s group if needed
  mkdir -p ${USER_HOME}/.kube
  sudo usermod -a -G microk8s $INSTALLER_USER
  sudo microk8s config > "${USER_HOME}/.kube/config"
  sudo chown -f -R $INSTALLER_USER ${USER_HOME}/.kube
fi

# Install NFS common package as we'll need it to mount NFS shares for pods to have storage
echo Installing NFS client on host for NFS PV support later
apt-get install -y nfs-common

# Wait for microk8s to get started and become ready
microk8s status --wait-ready > /dev/null && echo MicroK8s is started.

# Install the rbac, dns and dashboard plugins
echo Enabling the RBAC authorization mode, CoreDNS for internal DNS services and the Kubernetes Dashboard
microk8s enable rbac
microk8s enable dns
microk8s enable dashboard
microk8s enable cert-manager
microk8s disable ingress
microk8s disable hostpath-storage

# Update the kubernetes api server command line arguments to support OIDC, this requires a restart
echo Injecting OIDC startup arguments for kube-apiserver to allow validation of Google OIDC logins
echo '--oidc-issuer-url=https://accounts.google.com
--oidc-client-id=1041391019449-oa5p8pd37qg006a2hiv9pnp05h2ecen5.apps.googleusercontent.com
--oidc-username-claim=email' >> /var/snap/microk8s/current/args/kube-apiserver

echo Restarting Microk8s for OIDC update
microk8s stop; microk8s start &

# While waiting for microk8s to restart, download the OpenShift client cause we like it
if [ ! -f "/usr/local/bin/oc" ]; then
  mkdir dl_tmp
  cd dl_tmp

    ## Arm64
    #wget https://mirror.openshift.com/pub/openshift-v4/aarch64/clients/ocp-dev-preview/latest/openshift-client-linux.tar.gz
    #tar zxf ./openshift-client-linux.tar.gz

    # Amd64
    wget https://mirror.openshift.com/pub/openshift-v4/aarch64/clients/ocp-dev-preview/latest/openshift-client-linux-amd64.tar.gz
    tar zxf ./openshift-client-linux-amd64.tar.gz
    mv oc /usr/local/bin/oc

  cd ..
  rm -rf dl_tmp
else
  echo Sleeping 5 seconds to allow microk8s to get started ...
  sleep 5
fi

# Wait for microk8s to fully restart
microk8s status --wait-ready > /dev/null && echo MicroK8s is ready

echo Setting .kube/config
# Retrieve the admin token
#AUTH_TOKEN=$(microk8s config | grep token | cut -f2 -d':' | cut -f2 -d' ')
#AUTH_TOKEN=$(oc whoami -t)
AUTH_TOKEN="No longer available in this form"

# Do we need to create a wrapper script for 'microk8s kubectl' so kubectl-use is happy? This should generally already have been handled by the installation of the `oc` command above
if [ ! -f "/usr/local/bin/kubectl" ]; then
  echo Creating kubectl wrapper since it doesn\'t exist
  # Create wrapper in /usr/local/bin/kubectl
  echo '#!/usr/bin/env bash' > /usr/local/bin/kubectl
  echo 'exec microk8s kubectl $@' >> /usr/local/bin/kubectl
  chown root: /usr/local/bin/kubectl
  chmod 0755 /usr/local/bin/kubectl
fi

# Create initial basic namespaces for installing 3rd party components considered essential
echo Processing kubernetes objects . . .
process_resource_directory resources/00_namespaces
process_resource_directory resources/01_secrets

# Create critical services: ingress router, storage, ect and wait for them to start
process_resource_directory resources/02_bootstrap
echo -n "Waiting for nfs storage provider pod to start"
wait_for_pod kube-storage k8s-app=nfs-client-provisioner 600


# Install cert-manager operator for OpenShift routes
helm install openshift-routes -n cert-manager oci://ghcr.io/cert-manager/charts/openshift-routes
# Use the following annotations on routes to automagically secure them with cert-manager
#  annotations:
#    cert-manager.io/issuer-kind: ClusterIssuer
#    cert-manager.io/issuer-name: letsencrypt

# Create the dashboard route and then wait the dashboard and route to become available
process_resource_directory resources/10_baseservices

echo -n "Waiting for dashboard pod to start"
wait_for_pod kube-system k8s-app=kubernetes-dashboard 600

echo -n "Waiting for base routes to become available: "
echo -n " API"
while [[ $(microk8s kubectl get route -n default kubernetes-api -o 'jsonpath={..status.ingress[*].conditions[?(@.type=="Admitted")].status}') != "True" ]]; do echo -n . && sleep 1; done
echo -n " Dashboard-Token"
while [[ $(microk8s kubectl get route -n kube-system kubernetes-dashboard -o 'jsonpath={..status.ingress[*].conditions[?(@.type=="Admitted")].status}') != "True" ]]; do echo -n . && sleep 1; done
echo
echo -n " Dashboard-OIDC"
while [[ $(microk8s kubectl get route -n kube-oidc k8s-oidc-dash-proxy -o 'jsonpath={..status.ingress[*].conditions[?(@.type=="Admitted")].status}') != "True" ]]; do echo -n . && sleep 1; done
echo

process_resource_directory resources/50_general
echo "=== You may need to copy vault data files if the PVC has changed for vault after deployment ==="
echo -n "Waiting for authentication system (vault pod) to start"
wait_for_pod vault k8s-app=vault 600

echo Configuring vault authentication and kubernetes integration by logging into vault and running:
echo scripts/config-vault.sh

echo Adding admin rolebinding (dwimsey-admin) for david@wimsey.us as cluster-admin role
microk8s kubectl create clusterrolebinding dwimsey-admin --clusterrole=cluster-admin --user=david@wimsey.us

# Notify the user we're done and provide some basic instructions
cat << EOF

===============================================================================
Done!
===============================================================================

If this is the first time executing this script, you may need to logout and log back in again for all groups and
aliases to take effect.


===============================================================================
Required external configuration:
===============================================================================
DNS:
  storage.k8s.wimsey.us should point to the appropriate nfs server with /mnt/pool0/k8s exported for the NFS provisioner
  k8s.wimsey.us should point to the ingress IP for the cluster router - eventually this should be handled by keepalived

===============================================================================
Web Dashboard
===============================================================================

To login to the dashboard visit https://k8s.wimsey.us in your browser and login using your @wimsey.us Google accounts
or use the root token to login at https://k8s-token.wimsey.us in your browser and login using the following administrator token:

kubectl describe secret -n kube-system microk8s-dashboard-token
https://github.com/kubernetes/dashboard/blob/master/docs/user/access-control/creating-sample-user.md


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


Baseline services:
https://vault.wimsey.us - Hashicorp vault, Google for authentication, kubernetes integration enabled, all service accounts have basic login access and services by default
https://k8s.wimsey.us - Kubernetes dashboard using OIDC Auth via Google @wimsey.us accounts
https://k8s-token.wimsey.us - Direct route to kubernetes dashboard using token auth
https://kuberos.wimsey.us - OIDC Keys for Kubernetes authentication in kubectl
Murmur - Real time audio conferencing

Enjoy!

EOF

trap : 0
