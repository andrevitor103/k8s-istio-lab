# Módulo 07 — Resiliência

## Objetivo

Cortar uma chamada lenta, repetir uma chamada que devolve 503 e tirar de circulação um Pod que insiste no erro. Quem faz isso é o sidecar do storefront, na saída para o catalog.

## Conceitos

`timeout` no VirtualService é o teto da rota inteira. O catalog deste lab dorme quando recebe `delay_ms` (ou o header `x-delay-ms`). O storefront espera até 10 segundos no próprio cliente. Com timeout de 1 segundo no Envoy, a vitrine recebe a falha por volta desse 1 segundo.

`retries.attempts` é o número de tentativas extras. `perTryTimeout` limita cada uma. `retryOn: 5xx` cobre o 503 que o catalog devolve com `fail=1`.

Outlier detection mora na DestinationRule. Depois de `consecutive5xxErrors` respostas 5xx, o proxy para de mandar tráfego àquele Pod por `baseEjectionTime`. `maxEjectionPercent: 100` permite ejetar um Pod mesmo quando ele é metade do subset. O padrão, 10%, não ejetaria 1 de 2 Pods, e o exercício não apareceria.

O Pod ejetado continua `Ready` para o Kubernetes. A readiness olha `/ready`, que segue 200. Quem tira o Pod do rodízio é o Istio. O endpoint `/admin/sick` liga esse modo só naquele processo.

## Antes de começar

```bash
kubectl apply -k modules/07-resiliencia
kubectl rollout status deployment/catalog-v1 -n lab
kubectl rollout status deployment/storefront -n lab
```

Esse `apply` é o tráfego do módulo 06: 100% no subset `v1`, sem timeout curto. O gateway e o `/etc/hosts` continuam os do módulo 06.

## Passos

Meça uma chamada lenta sem regra de timeout:

```bash
curl -s "http://store.lab.test/item?delay_ms=3000"
```

`latency_ms` fica perto de 3000 e `catalog.version` é `v1`.

## Exercício

### Timeout

Escreva um VirtualService `catalog` com `timeout: 1s` e o destino no subset `v1`. Aplique e repita o `curl` com `delay_ms=3000`.

A referência é [solucao/virtualservice-timeout.yaml](solucao/virtualservice-timeout.yaml).

```bash
kubectl apply -f modules/07-resiliencia/solucao/virtualservice-timeout.yaml
curl -s "http://store.lab.test/item?delay_ms=3000"
```

A latência cai para cerca de 1000 ms e o status deixa de ser o JSON do item. O corpo vem do Envoy (timeout upstream). Uma chamada sem atraso continua ok:

```bash
curl -s http://store.lab.test/item
```

### Retry

Troque a rota por uma com 2 tentativas extras em `5xx`. Uma chamada com `fail=1` falha para o cliente, e o catalog registra mais de um acesso.

A referência é [solucao/virtualservice-retry.yaml](solucao/virtualservice-retry.yaml).

```bash
kubectl apply -f modules/07-resiliencia/solucao/virtualservice-retry.yaml
kubectl logs -n lab -l app=catalog,version=v1 -c catalog --tail=5
curl -s "http://store.lab.test/item?fail=1"
kubectl logs -n lab -l app=catalog,version=v1 -c catalog --tail=20
```

Um `curl` produz três linhas `503` somando os Pods v1: a tentativa original e duas retries. O storefront devolve um único erro.

### Outlier detection

Volte o VirtualService ao arquivo do módulo 06 (100% v1, sem retry) e aplique a DestinationRule com ejeção. Marque um único Pod v1 como doente e mande tráfego limpo.

A referência é [solucao/destinationrule-outlier.yaml](solucao/destinationrule-outlier.yaml).

```bash
kubectl apply -f modules/06-traffic/virtualservice-catalog.yaml
kubectl apply -f modules/07-resiliencia/solucao/destinationrule-outlier.yaml

POD=$(kubectl get pod -n lab -l app=catalog,version=v1 -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n lab "$POD" -c catalog -- python -c 'import urllib.request; print(urllib.request.urlopen("http://127.0.0.1:8080/admin/sick").read().decode())'

for i in $(seq 1 20); do curl -s -o /dev/null -w "%{http_code}\n" http://store.lab.test/item; done
```

Os primeiros códigos misturam 200 e 503. Depois da ejeção, passam a 200: o proxy do storefront evita o Pod doente e fica no outro v1.

O Pod doente segue `Running` e `Ready`:

```bash
kubectl get pod -n lab "$POD"
```

No proxy do storefront, o endpoint deixa de aparecer como saudável:

```bash
STORE=$(kubectl get pod -n lab -l app=storefront -o jsonpath='{.items[0].metadata.name}')
istioctl proxy-config endpoints -n lab "$STORE" | grep catalog
```

Cure o processo e restaure as regras da aula:

```bash
kubectl exec -n lab "$POD" -c catalog -- python -c 'import urllib.request; print(urllib.request.urlopen("http://127.0.0.1:8080/admin/healthy").read().decode())'
kubectl apply -k modules/07-resiliencia
```

A ejeção expira sozinha em cerca de 30 segundos (`baseEjectionTime`). O `apply` devolve a DestinationRule sem outlier detection.

## Perguntas

1. Por que o timeout do VirtualService responde antes dos 10 segundos do storefront?
2. O que `attempts: 2` conta: o total de chamadas ou as repetições?
3. Por que a readiness do Kubernetes não esconde o Pod doente?

## Limpeza

```bash
kubectl apply -k modules/07-resiliencia
```

Esse comando reaplica o tráfego do módulo 06 por cima do timeout, do retry e do outlier. Para apagar a aplicação inteira, use a limpeza do módulo 06.

## Respostas

1. O sidecar do storefront é o cliente que o catalog enxerga. Ele cancela a rota no limite do VirtualService e devolve o erro para o processo da vitrine.
2. As repetições. `attempts: 2` faz no máximo três idas ao catalog.
3. `/ready` continua 200. A readiness não olha o 503 de `/items`. O outlier detection olha.
