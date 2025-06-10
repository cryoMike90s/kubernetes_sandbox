#!/bin/bash
set -e

git clone https://github.com/ahmetb/kubectx
chmod +x ./kubectx/kubectx
chmod +x ./kubectx/kubens
cp kubectx/kubectx /usr/local/bin/kubectx
cp kubectx/kubens /usr/local/bin/kubens
rm -rf kubectx
