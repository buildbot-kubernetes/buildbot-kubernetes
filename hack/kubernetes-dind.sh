#!/bin/bash

curl -o dind-cluster-${KUBE_VERSION}.sh https://cdn.rawgit.com/kubernetes-sigs/kubeadm-dind-cluster/master/fixed/dind-cluster-${KUBE_VERSION}.sh
curl -o portforward.sh https://cdn.jsdelivr.net/gh/kubernetes-sigs/kubeadm-dind-cluster@master/build/portforward.sh
chmod +x dind-cluster-${KUBE_VERSION}.sh
chmod +x portforward.sh
./portforward.sh start
export DIND_PORT_FORWARDER_WAIT=1
export DIND_PORT_FORWARDER="${PWD}/portforward.sh"
./dind-cluster-${KUBE_VERSION}.sh up
