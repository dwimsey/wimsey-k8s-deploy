
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

# Optionally - this requires the ExtendedResourceAdmission controller also be enabled in order for nodes
# requesting access to GPUs to be able to run on GPU nodes
kubectl taint nodes -l nvidia.com/gpu.present=true nvidia.com/gpu=true:NoSchedule
```
GPU Resources
=============

If any hosts have nVidia GPUs in them - these setup options will make usage of those resources more streamlined.

First prepare the host for microk8s, but do not run the worker setup script.  ssh to the host host and run
```shell
sudo ./wimsey-k8s-deploy/host-setup/10-gpu-nvidia.sh
# Wait for reboot
sudo ./wimsey-k8s-deploy/host-setup/11-gpu-nvidia.sh
```

The nVidia operator will detect which nodes have GPUs and label them appropriately.  In addition the operator provides
Extended Resource `nvidia.com/gpu`, which can be used in a pod template for resource.request.  By requesting this resource,
the pod will be scheduled on a node which has a GPU resource.

If using the nVidia GPU operator, adding the `ExtendedResourcesTolerations` admission controller is recommended, this will cut down on the effort required to assign pods the correct tolerations for GPU.  If the request a GPU resource via resources.request.nvidia.com/gpu , the appropiate taint tolerations will be added to the pod so that it will be allowed to use a GPU capable node

Once the ExtendedResourcesTolerations admission controller is configured.  You can `taint` the GPU nodes with this command, and the admission controller will add the appropriate toleration to pods which request use of `nvidia.com/gpu` resources.

```shell
kubectl taint node -l nvidia.com/gpu.present nvidia.com/gpu:NoSchedule
```

Pods that want to run on GPU only nodes should use this node selector and toleration:
```yaml
      nodeSelector:
        nvidia.com/gpu.present: "true"
```

GPU Replicas
=============

By default each GPU is available to only a single pod at a time.  The nVidia GPI operator can be configured to share GPUs.  For
this cluster, this is done using a cluster wide policy for the operatore


Then patch the operator to use the new policy like this:
```shell
kubectl apply -n gpu-operator-resources -f resources/999_experimental/gpu/operator-gpu-replicas.yml
kubectl patch -n gpu-operator-resources clusterpolicies.nvidia.com/cluster-policy --type merge  -p '{"spec": {"devicePlugin": {"config": {"name": "time-slicing-config-all", "default": "any"}}}}'
```

DaemonSets will not schedule on tainted nodes
=============================================

DaemonSets will not schedule on GPU tainted nodes, the toleration must be added manually to DaemonSets:
```yaml
      nodeSelector:
        nvidia.com/gpu.present: "true"
      tolerations:
        - key: nvidia.com/gpu
          operator: Exists
          effect: NoSchedule
```