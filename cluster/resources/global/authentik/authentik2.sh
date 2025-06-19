#helm repo add authentik https://charts.goauthentik.io
#helm repo update
helm dependency update
helm upgrade --install my-authentik . -f values.yaml -n auth --create-namespace
