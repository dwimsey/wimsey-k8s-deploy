
Deploy master / control node
============================
```shell
# Checkout repo
git clone https://github.com/dwimsey/wimsey-k8s-deploy.git
cd wimsey-k8s-deploy

# Recover core secrets not in vault
scp storage:bootstrap/01_secrets/\* resources/01_secrets/

# Do base updates, install requirements
./host-setup/deploy-ubuntu.sh k8s-cp-00.wimsey.us

# Perform microk8s base setup
ssh -t k8s-cp-00.wimsey.us ./setup-microk8s-main.sh
```

Deploy worker node
==================
```shell
# Do base updates, install requirements
./host-setup/deploy-ubuntu.sh k8s-app-00

./setup-microk8s-worker.sh k8s-app-00
```

For GPU Support
===============
```shell
# Install updates and driver blacklisting which requires rebooting ...
ssh -t k8s-gpu-app-03.wimsey.us sudo ./wimsey-k8s-deploy/host-setup/10-gpu-nvidia.sh
# wait for reboot ...
# Install the nVidia gpu driver and cuda frameworks
ssh -t k8s-gpu-app-03.wimsey.us sudo ./wimsey-k8s-deploy/host-setup/11-gpu-nvidia.sh
```

Enable the GPU operator
=======================
```shell
# This will enable the nVidia operator to mark nodes and perform various gpu related tasks
# Execute on a control node
microk8s enable nvidia --gpu-operator-driver host --gpu-operator-set driver.enabled=false
```
