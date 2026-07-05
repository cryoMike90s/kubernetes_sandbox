#!/bin/bash

set -a
source .env
set +a

flux bootstrap git \
  --url=ssh://git@github.com/cryoMike90s/kubernetes_sandbox.git \
  --branch=main \
  --private-key-file=$GITHUB_PRIVATE_KEY_FILE \
  --path=clusters/sandbox \
  --components-extra="image-reflector-controller,image-automation-controller"
