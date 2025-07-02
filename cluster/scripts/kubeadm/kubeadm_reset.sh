#!/bin/bash
set -e

kubeadm reset -f

rm -rf $HOME:/etc/cni/net.d/10-calico.conflist
rm -rf $HOME:/etc/cni/net.d/calico-kubeconfig

sudo swapoff -a
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

ctr -n k8s.io i rm $(ctr -n k8s.io i ls -q)

sudo systemctl restart containerd

rm -rf $HOME/.kube/config
