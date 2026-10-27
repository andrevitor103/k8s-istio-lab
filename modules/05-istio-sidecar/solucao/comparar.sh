#!/usr/bin/env bash
# Referência do exercício: compare um Pod com sidecar e um Pod sem injeção.
set -euo pipefail

kubectl create namespace fora --dry-run=client -o yaml | kubectl apply -f -
kubectl delete pod -n fora catalog-fora --ignore-not-found
kubectl run catalog-fora -n fora \
  --image=catalog:lab \
  --image-pull-policy=IfNotPresent \
  --restart=Never \
  --env=VERSION=v1 \
  --labels=app=catalog \
  --command -- python -u /app/app.py

kubectl wait -n fora --for=condition=Ready pod/catalog-fora --timeout=60s

echo
echo "=== lab (com injeção) ==="
kubectl get pods -n lab \
  -o custom-columns=NAME:.metadata.name,READY:.status.containerStatuses[*].ready,CONTAINERS:.spec.containers[*].name,INIT:.spec.initContainers[*].name

echo
echo "=== fora (sem label istio-injection) ==="
kubectl get pod -n fora catalog-fora \
  -o custom-columns=NAME:.metadata.name,READY:.status.containerStatuses[*].ready,CONTAINERS:.spec.containers[*].name,INIT:.spec.initContainers[*].name

echo
echo "Apagando o namespace fora."
kubectl delete namespace fora --wait=false
