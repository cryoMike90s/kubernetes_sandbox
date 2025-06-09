helm repo add kubeblocks https://apecloud.github.io/helm-charts
helm install my-csi-driver-nfs kubeblocks/csi-driver-nfs --namespace kube-system --version 4.10.0
