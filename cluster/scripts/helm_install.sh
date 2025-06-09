export HELM_VERSION=$(curl -s "https://api.github.com/repos/helm/helm/releases/latest" | \grep -Po '"tag_name": *"v\K[^"]*')
curl -Lo helm-${HELM_VERSION}-linux-amd64.tar.gz "https://get.helm.sh/helm-v${HELM_VERSION}-linux-amd64.tar.gz"
tar -zxvf helm-${HELM_VERSION}-linux-amd64.tar.gz
chmod +x linux-amd64/helm
mv linux-amd64/helm /usr/local/bin
rm -rf linux-amd64
rm helm-${HELM_VERSION}-linux-amd64.tar.gz
