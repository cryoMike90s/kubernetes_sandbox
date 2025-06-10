helm repo add bitnami https://charts.bitnami.com/bitnami

helm upgrade --install \
  -n db-dev \
  postgres bitnami/postgresql \
  --set auth.postgresPassword=haslo \
  --set global.defaultStorageClass=nfs-csi-db \
  --version 16.5.2 \
  --values values.yaml \
  --create-namespace
