helm repo add kubeblocks https://apecloud.github.io/helm-charts
helm install my-csi-driver-nfs kubeblocks/csi-driver-nfs --namespace kube-system --set controller.runOnControlPlane=true --version 4.10.0

# helm delete my-csi-driver-nfs -n kube-system
