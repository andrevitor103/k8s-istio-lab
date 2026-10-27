#!/usr/bin/env bash
# Instala o ingress-nginx com os valores de kind deste laboratório.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PATH="${HOME}/.local/bin:${PATH}"

helm upgrade --install ingress-nginx ingress-nginx \
  --repo https://kubernetes.github.io/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --values "${ROOT}/cluster/ingress-nginx-values.yaml" \
  --wait \
  --timeout 5m

kubectl get pods -n ingress-nginx
echo "Ingress pronto. O host store.lab.test aponta para 127.0.0.1 (veja o módulo 04)."
