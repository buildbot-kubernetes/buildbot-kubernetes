#!/bin/bash

curl -Lo dind-cluster-${KUBE_VERSION}.sh https://github.com/kubernetes-sigs/kubeadm-dind-cluster/releases/download/v0.1.0/dind-cluster-${KUBE_VERSION}.sh
curl -Lo portforward.sh https://raw.githubusercontent.com/kubernetes-sigs/kubeadm-dind-cluster/v0.1.0/build/portforward.sh
chmod +x dind-cluster-${KUBE_VERSION}.sh
chmod +x portforward.sh
./portforward.sh start
export DIND_PORT_FORWARDER_WAIT=1
export DIND_PORT_FORWARDER="${PWD}/portforward.sh"
./dind-cluster-${KUBE_VERSION}.sh up
