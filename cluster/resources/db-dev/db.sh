helm repo add bitnami https://charts.bitnami.com/bitnami

helm upgrade --install \
  -n db-dev \
  postgres bitnami/postgresql \
  --version 16.5.2 \
  --values values.yaml \
  --create-namespace
