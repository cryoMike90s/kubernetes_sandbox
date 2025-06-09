kubectl apply -f namespace.yaml
kubectl apply -f pV.yaml

helm repo add bitnami https://charts.bitnami.com/bitnami

helm upgrade --install \
  -n postgres \
  postgres bitnami/postgresql \
  --set auth.postgresPassword=haslo \
  --version 16.5.2 \
  --values values.yaml
