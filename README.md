# Laboratório Kubernetes + Istio

Estudo local, em ordem. Cada módulo tem um guia, os manifestos para aplicar e, quando o exercício pede um YAML, a referência em `solucao/`.

O app tem dois serviços. `catalog` devolve um item e a própria versão (`v1` ou `v2`). `storefront` chama o catalog pela DNS do cluster e mostra a versão e a latência. As imagens são locais (`catalog:lab` e `storefront:lab`), carregadas no kind com `kind load`.

## Ordem

1. [00 Ambiente](modules/00-ambiente/README.md) — cluster kind, contexto, namespace `lab`
2. [01 Pod e Deployment](modules/01-pod-deployment/README.md) — ciclo de vida, labels, réplicas
3. [02 Service](modules/02-service/README.md) — ClusterIP, DNS, endpoints
4. [03 Dois serviços](modules/03-dois-servicos/README.md) — ConfigMap e probes
5. [04 Ingress](modules/04-ingress/README.md) — entrada HTTP antes da mesh
6. [05 Istio sidecar](modules/05-istio-sidecar/README.md) — instalação e o que o Envoy faz no Pod
7. [06 Tráfego](modules/06-traffic/README.md) — Gateway, VirtualService, canário
8. [07 Resiliência](modules/07-resiliencia/README.md) — timeout, retry, outlier detection
9. [08 mTLS](modules/08-mtls/README.md) — PeerAuthentication e AuthorizationPolicy
10. [09 Observabilidade](modules/09-observabilidade/README.md) — Kiali, Prometheus, Jaeger

Módulos 00 a 04 levam alguns dias. Os de Istio cabem na semana seguinte. A mesh entra depois do Ingress para o problema ficar visível: uma porta de entrada ainda não decide timeout, identidade nem divisão de tráfego entre os Pods.

## Máquina

Reserve cerca de 8 GB de RAM livres. O perfil `demo` do Istio, mais Kiali, Prometheus e Jaeger, fica apertado em 4 GB. O cluster sobe com 1 control-plane e 2 workers.

As portas 80 e 443 de `127.0.0.1` precisam estar livres na hora do `make cluster-up`.

## Primeiros comandos

Na raiz deste diretório:

```bash
export PATH="$HOME/.local/bin:$PATH"
make prereqs
make cluster-up
make apps
```

`make prereqs` confere o Docker e instala kubectl, kind, helm e istioctl em `~/.local/bin` quando ainda não estão no PATH. O Istio baixado fica em `.istio/` (ignorado pelo git) e o caminho da release fica em `.istio-home`.

Inclua o `export PATH` no seu `~/.bashrc` se o shell novo não achar os binários.

## Alvos do Makefile

| Alvo | Uso |
| --- | --- |
| `make prereqs` | ferramentas |
| `make cluster-up` / `make cluster-down` | cria ou apaga o cluster `k8s-istio-lab` |
| `make apps` | build e `kind load` das duas imagens |
| `make ingress-nginx` | controller do módulo 04 |
| `make istio-up` / `make istio-down` | perfil demo e a remoção |
| `make istio-gateway` | publica o gateway em `127.0.0.1:80` |
| `make observability` / `make observability-down` | Kiali, Prometheus e Jaeger |

## Reset

Para esvaziar só o exercício, use o comando de limpeza do módulo. Para recomeçar o cluster inteiro:

```bash
make cluster-down
make cluster-up
make apps
```

O contexto do kubectl passa a ser `kind-k8s-istio-lab`.
