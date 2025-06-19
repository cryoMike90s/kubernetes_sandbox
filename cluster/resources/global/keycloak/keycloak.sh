helm repo add bitnami https://charts.bitnami.com/bitnami
helm upgrade --install keycloak --namespace keycloak bitnami/keycloak -f values.yaml
