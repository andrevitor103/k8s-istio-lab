#!/usr/bin/env bash
# Instala ou remove Kiali, Prometheus e Jaeger a partir dos samples da release baixada.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PATH="${HOME}/.local/bin:${PATH}"
HOME_FILE="${ROOT}/.istio-home"

if [[ ! -s "${HOME_FILE}" ]]; then
  echo "Falta ${HOME_FILE}. Rode: make prereqs" >&2
  exit 1
fi

ISTIO_HOME="$(cat "${HOME_FILE}")"
ADDONS="${ISTIO_HOME}/samples/addons"

if [[ ! -d "${ADDONS}" ]]; then
  echo "Não achei ${ADDONS}." >&2
  echo "A documentação da sua release está em https://istio.io/latest/docs/ops/integrations/kiali/" >&2
  istioctl version --short || true
  exit 1
fi

addon_file() {
  local name="$1"
  local path="${ADDONS}/${name}.yaml"
  if [[ ! -f "${path}" ]]; then
    echo "Arquivo ausente: ${path}" >&2
    exit 1
  fi
  printf '%s\n' "${path}"
}

FILES=(
  "$(addon_file prometheus)"
  "$(addon_file jaeger)"
  "$(addon_file kiali)"
)

if [[ "${1:-}" == "--delete" ]]; then
  kubectl delete -f "${FILES[2]}" --ignore-not-found
  kubectl delete -f "${FILES[1]}" --ignore-not-found
  kubectl delete -f "${FILES[0]}" --ignore-not-found
  exit 0
fi

# A primeira aplicação pode falhar enquanto os CRDs ainda não existem.
# A própria documentação do Istio manda aplicar de novo.
kubectl apply -f "${FILES[0]}" || true
kubectl apply -f "${FILES[1]}" || true
kubectl apply -f "${FILES[2]}" || true
sleep 4
kubectl apply -f "${FILES[0]}"
kubectl apply -f "${FILES[1]}"
kubectl apply -f "${FILES[2]}"

kubectl rollout status deployment/prometheus -n istio-system --timeout=180s
kubectl rollout status deployment/kiali -n istio-system --timeout=180s
kubectl get pods -n istio-system
echo
echo "Abra os painéis com:"
echo "  istioctl dashboard kiali"
echo "  istioctl dashboard prometheus"
echo "  istioctl dashboard jaeger"
