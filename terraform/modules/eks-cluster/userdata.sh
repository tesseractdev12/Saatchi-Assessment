#!/bin/bash
set -o xtrace

# Bootstrap the EKS node
/etc/eks/bootstrap.sh ${cluster_name} ${bootstrap_arguments}

# Enable kubelet extra args for network policy enforcement
echo "KUBELET_EXTRA_ARGS=--enable-network-policy=true" >> /etc/sysconfig/kubelet

# Restart kubelet
systemctl restart kubelet
