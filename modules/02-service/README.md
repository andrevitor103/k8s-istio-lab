# Módulo 02 — Service

## Objetivo

Dar um endereço estável ao catalog. O cliente fala com o Service; o kube-proxy reparte entre os Pods que batem no selector.

## Conceitos

`ClusterIP` é um IP virtual, visível só de dentro do cluster. Ele não muda quando um Pod morre.

O `selector` escolhe os Pods. Cada Pod compatível vira um endpoint. Tráfego para `catalog:8080` cai num desses endpoints.

A DNS do cluster responde `catalog.lab.svc.cluster.local`. No mesmo namespace, o nome curto `catalog` também resolve.

O campo `name: http` da porta diz o protocolo. No módulo 05 o Istio usa esse nome para tratar a conexão como HTTP. `targetPort: http` aponta para a porta nomeada do container.

`kubectl port-forward` abre um túnel da sua máquina até o Service. Serve para olhar o app antes de existir Ingress.

## Antes de começar

```bash
make apps
```

## Passos

```bash
kubectl apply -k modules/02-service
kubectl rollout status deployment/catalog -n lab
kubectl get svc,endpoints,pods -n lab -o wide
```

Anote o `CLUSTER-IP` e os endereços em `ENDPOINTS`. Apague um Pod e olhe de novo:

```bash
kubectl delete pod -n lab -l app=catalog --wait=false
kubectl get pods,endpoints -n lab
```

O ClusterIP permanece. A lista de endpoints troca o IP do Pod que morreu pelo IP do Pod novo.

De dentro de um Pod, use a DNS:

```bash
kubectl exec -n lab deploy/catalog -- python -c 'import urllib.request; print(urllib.request.urlopen("http://catalog.lab.svc.cluster.local:8080/items/1").read().decode())'
```

Da sua máquina:

```bash
kubectl port-forward -n lab svc/catalog 18080:8080
```

Noutro terminal:

```bash
curl -s http://127.0.0.1:18080/items/1
```

`Ctrl+C` encerra o port-forward.

## O que observar

- `ENDPOINTS` lista `ip-do-pod:8080`, um por réplica pronta.
- O Service não tem os IPs dos Pods escritos no YAML. Ele os descobre pelo selector.
- A resposta JSON traz `"version": "v1"`.

## Exercício

Crie um segundo Service, `catalog-headless`, com `clusterIP: None` e o mesmo selector. Aplique, compare os endpoints e a DNS, e apague esse Service no fim.

A referência está em [solucao/service-headless.yaml](solucao/service-headless.yaml).

```bash
kubectl apply -f modules/02-service/solucao/service-headless.yaml
kubectl get svc,endpoints -n lab
kubectl exec -n lab deploy/catalog -- python -c 'import socket; print(socket.getaddrinfo("catalog-headless", 8080))'
kubectl delete svc catalog-headless -n lab
```

No Service normal, a DNS devolve o ClusterIP. No headless, a DNS devolve os IPs dos Pods. O lab segue com o ClusterIP `catalog`.

## Perguntas

1. Por que o storefront, no próximo módulo, vai usar um nome e uma porta, e não um IP de Pod?
2. O que acontece com o Service se as duas réplicas estiverem `Pending`?
3. Para que serve o nome `http` na porta, se o número 8080 já bastaria para o kube-proxy?

## Limpeza

```bash
kubectl delete -k modules/02-service
```

## Respostas

1. O nome continua válido quando os Pods são trocados. O IP de Pod não.
2. O ClusterIP existe, e a lista de endpoints fica vazia. Conexões novas não têm para onde ir.
3. O kube-proxy usa o número. O Istio usa o nome para decidir o protocolo. Sem nome, a mesh trata a porta como TCP opaco e as regras HTTP dos módulos 06 e 07 não se aplicam.
