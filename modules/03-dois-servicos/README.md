# Módulo 03 — Dois serviços

## Objetivo

Fazer o storefront chamar o catalog pelo nome do Service. A URL fica num ConfigMap. Uma readiness probe tira o Pod do Service quando o processo diz que não pode receber tráfego.

## Conceitos

ConfigMap guarda configuração que não é segredo. O Deployment lê a chave `CATALOG_URL` e injeta a env `CATALOG_URL` no container. Mudar o ConfigMap não reinicia o Pod sozinho: o processo só vê o valor novo quando sobe de novo.

A liveness probe responde “o processo precisa ser morto?”. A readiness probe responde “este Pod pode entrar no Service?”. As duas batem em portas diferentes do mesmo app de propósito:

- `/health` fica 200 enquanto o processo está de pé.
- `/ready` devolve 503 quando `READY=false`.

Com `failureThreshold: 1`, uma falha já tira o Pod dos endpoints. O padrão do Kubernetes é 3, o que alonga o exercício.

O storefront usa a biblioteca padrão do Python. Um timeout de 10 segundos no cliente é a rede de segurança da aplicação. Mais adiante o Istio corta antes disso.

## Antes de começar

```bash
make apps
```

## Passos

```bash
kubectl apply -k modules/03-dois-servicos
kubectl rollout status deployment/catalog -n lab
kubectl rollout status deployment/storefront -n lab
kubectl get pods,svc,endpoints -n lab
```

```bash
kubectl port-forward -n lab svc/storefront 18081:8080
```

Noutro terminal:

```bash
curl -s http://127.0.0.1:18081/item
```

A resposta traz `storefront`, `latency_ms` e `catalog.version`. Encerre o port-forward com `Ctrl+C`.

Olhe a env que o ConfigMap virou:

```bash
kubectl exec -n lab deploy/storefront -- python -c 'import os; print(os.environ["CATALOG_URL"])'
```

## O que observar

- Os endpoints de `catalog` têm dois endereços. Os de `storefront`, um.
- O storefront não conhece IP de Pod. A URL aponta para `catalog.lab.svc.cluster.local`.
- Os logs do catalog mostram a chamada chegando: `kubectl logs -n lab -l app=catalog --tail=20`.

## Exercício

Faça a readiness do catalog falhar e veja os endpoints esvaziarem, com os Pods ainda `Running`.

A referência está em [solucao/catalog.yaml](solucao/catalog.yaml): a env `READY` passa a `false`. `/health` continua 200, então a liveness não reinicia o container.

```bash
kubectl apply -f modules/03-dois-servicos/solucao/catalog.yaml
kubectl rollout status deployment/catalog -n lab
kubectl get pods,endpoints -n lab
```

Os Pods ficam `Running` com a coluna `READY` em `0/1`. `catalog` deixa de listar endpoints. Uma chamada do storefront falha porque não há destino.

Restaure o módulo:

```bash
kubectl apply -k modules/03-dois-servicos
kubectl rollout status deployment/catalog -n lab
```

## Perguntas

1. Por que a liveness em `/health` não reinicia o Pod neste exercício?
2. O que muda para o Service quando a readiness falha?
3. Se você editar o ConfigMap e não reiniciar o storefront, qual URL o processo ainda usa?

## Limpeza

```bash
kubectl delete -k modules/03-dois-servicos
```

## Respostas

1. `/health` continua 200. A liveness só age quando o caminho dela falha, ou quando o processo morre.
2. O Pod sai da lista de endpoints. O ClusterIP continua existindo.
3. A URL antiga. Env vinda de ConfigMap é lida na criação do container.
