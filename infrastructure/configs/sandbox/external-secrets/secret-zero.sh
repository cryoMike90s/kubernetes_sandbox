#!/bin/bash

set -a
source .env
set +a

kubectl create secret generic sandbox-auth-credentials -n external-secrets \
  --from-literal=clientID="$SANDBOX_CLIENT_ID" \
  --from-literal=clientSecret="$SANDBOX_CLIENT_SECRET"
