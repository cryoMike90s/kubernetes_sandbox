helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx

helm install -n ingress-controller ingress-nginx ingress-nginx/ingress-nginx --create-namespace
