#!/usr/bin/env bash
# Confere Docker, kubectl, kind, helm e istioctl.
# Instala o que faltar em ~/.local/bin, nas versões stable publicadas no dia.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN_DIR="${HOME}/.local/bin"
mkdir -p "${BIN_DIR}"
export PATH="${BIN_DIR}:${PATH}"

OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
case "$(uname -m)" in
  x86_64) ARCH="amd64" ;;
  aarch64 | arm64) ARCH="arm64" ;;
  *)
    echo "Arquitetura não suportada: $(uname -m)" >&2
    exit 1
    ;;
esac

if [[ "${OS}" != "linux" ]]; then
  echo "Este script cobre Linux. Sistema encontrado: ${OS}" >&2
  exit 1
fi

install_kubectl() {
  local stable tmp sha
  stable="$(curl -fsSL https://dl.k8s.io/release/stable.txt | tr -d '[:space:]')"
  tmp="$(mktemp)"
  echo "Instalando kubectl ${stable}..."
  curl -fsSL -o "${tmp}" "https://dl.k8s.io/release/${stable}/bin/linux/${ARCH}/kubectl"
  sha="$(curl -fsSL "https://dl.k8s.io/release/${stable}/bin/linux/${ARCH}/kubectl.sha256")"
  echo "${sha}  ${tmp}" | sha256sum --check
  chmod 0755 "${tmp}"
  mv "${tmp}" "${BIN_DIR}/kubectl"
}

install_kind() {
  local tmp
  tmp="$(mktemp)"
  echo "Instalando kind (release latest)..."
  curl -fsSL -o "${tmp}" "https://kind.sigs.k8s.io/dl/latest/kind-linux-${ARCH}"
  chmod 0755 "${tmp}"
  mv "${tmp}" "${BIN_DIR}/kind"
}

install_helm() {
  echo "Instalando Helm 3 (script oficial)..."
  curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 \
    | USE_SUDO=false HELM_INSTALL_DIR="${BIN_DIR}" bash
}

install_istioctl() {
  local dest extracted
  dest="${ROOT}/.istio"
  mkdir -p "${dest}"
  rm -rf "${dest}"/istio-*
  echo "Baixando o Istio stable (istioctl e samples dos addons)..."
  (
    cd "${dest}"
    curl -fsSL https://istio.io/downloadIstio | sh -
  )
  extracted="$(find "${dest}" -mindepth 1 -maxdepth 1 -type d -name 'istio-*' | head -n 1)"
  if [[ -z "${extracted}" || ! -x "${extracted}/bin/istioctl" ]]; then
    echo "O download do Istio não deixou bin/istioctl." >&2
    exit 1
  fi
  install -m 0755 "${extracted}/bin/istioctl" "${BIN_DIR}/istioctl"
  printf '%s\n' "${extracted}" > "${ROOT}/.istio-home"
}

if command -v kubectl >/dev/null 2>&1; then
  echo "kubectl já está no PATH."
else
  install_kubectl
fi

if command -v kind >/dev/null 2>&1; then
  echo "kind já está no PATH."
else
  install_kind
fi

if command -v helm >/dev/null 2>&1; then
  echo "helm já está no PATH."
else
  install_helm
fi

if command -v istioctl >/dev/null 2>&1 && [[ -s "${ROOT}/.istio-home" ]]; then
  echo "istioctl já está no PATH e os samples locais existem."
else
  install_istioctl
fi

echo
echo "Versões:"
kubectl version --client
kind version
helm version --short
istioctl version --remote=false --short

if ! command -v docker >/dev/null 2>&1; then
  echo "Docker não está instalado. Instale o Docker Engine e rode de novo." >&2
  exit 1
fi

if ! docker info >/dev/null 2>&1; then
  echo "O binário do Docker existe, mas o daemon não responde." >&2
  echo "Inicie o serviço (sudo systemctl start docker) e confira o grupo docker do seu usuário." >&2
  exit 1
fi

echo
echo "Docker ok: $(docker version --format 'cliente {{.Client.Version}} / daemon {{.Server.Version}}')"
echo "Binários deste lab: ${BIN_DIR}"
case ":${PATH}:" in
  *":${BIN_DIR}:"*) ;;
  *)
    echo "Inclua no seu shell: export PATH=\"${BIN_DIR}:\$PATH\""
    ;;
esac
