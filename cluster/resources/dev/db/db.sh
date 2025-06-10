kubectl apply -f namespace.yaml
#kubectl apply -f StorageClass.yaml
helm repo add bitnami https://charts.bitnami.com/bitnami

helm upgrade --install \
  -n postgres \
  postgres bitnami/postgresql \
  --set auth.postgresPassword=haslo \
  --set global.defaultStorageClass=nfs-csi-db \
  --version 16.5.2 \
  --values values.yaml
