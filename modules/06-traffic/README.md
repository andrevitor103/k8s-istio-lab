# Módulo 06 — Tráfego

## Objetivo

Trocar o Ingress pelo gateway do Istio e mandar uma fração das chamadas do storefront para o catalog `v2`. O peso da rota é uma decisão do Envoy, não da quantidade de réplicas.

## Conceitos

`Gateway` seleciona o proxy de borda (`istio: ingressgateway`) e o host que ele aceita. `VirtualService` `storefront` liga esse host ao Service da vitrine. Esse par ocupa o lugar do Ingress.

`DestinationRule` parte o Service `catalog` em subsets. O subset `v1` são os Pods com `version: v1`. O `VirtualService` `catalog` não tem `gateways`: ele vale para o tráfego interno da mesh, que é a chamada do storefront.

O selector de cada Deployment inclui `version`. Se os dois usassem só `app: catalog`, os ReplicaSets disputariam os mesmos Pods. O Service, esse sim, seleciona só `app: catalog`, para os dois subsets serem endpoints do mesmo nome.

A Gateway API do Kubernetes (`HTTPRoute`) também fala com o Istio. Os objetos deste módulo são os da API do Istio (`networking.istio.io`). É com eles que timeout, retry e canário aparecem nos exercícios.

## Antes de começar

O módulo 05 está aplicado: `istio-injection=enabled` em `lab` e `istioctl proxy-status` enxerga os proxies.

A porta 80 do nó está com o ingress-nginx. Solte ela antes do gateway:

```bash
kubectl delete -k modules/04-ingress
kubectl delete namespace ingress-nginx --wait
```

O Deployment antigo se chama `catalog` e o selector dele é só `app: catalog`. Ele adotaria os Pods da v2. Apague antes de aplicar este módulo:

```bash
kubectl delete deployment catalog -n lab --ignore-not-found
```

A linha de `/etc/hosts` do módulo 04 continua valendo (`127.0.0.1 store.lab.test`).

## Passos

```bash
make istio-gateway
kubectl apply -k modules/06-traffic
kubectl rollout status deployment/catalog-v1 -n lab
kubectl rollout status deployment/catalog-v2 -n lab
kubectl rollout status deployment/storefront -n lab
kubectl get pods -n lab -L version
```

Confira que os Pods novos têm proxy (`2/2` ou init `istio-proxy`).

```bash
for i in $(seq 1 10); do curl -s http://store.lab.test/item; echo; done
```

Todas as linhas trazem `"version": "v1"`. A v2 está de pé e o VirtualService ainda não manda nada para ela.

## O que observar

- `kubectl get svc -n istio-system istio-ingressgateway` pode continuar `<pending>`. A entrada que funciona é o `hostPort` configurado por `make istio-gateway`, no nó `ingress-ready`.
- `kubectl get gateway,virtualservice,destinationrule -n lab` lista os quatro objetos.
- O peso não está no Deployment. As duas versões têm 2 réplicas. Quem escolhe é a rota.

## Exercício

Edite o VirtualService `catalog` para 90% em `v1` e 10% em `v2`. Rode o laço de `curl` de novo e conte as versões. Em seguida passe para 50/50.

As referências:

- [solucao/virtualservice-catalog-90-10.yaml](solucao/virtualservice-catalog-90-10.yaml)
- [solucao/virtualservice-catalog-50-50.yaml](solucao/virtualservice-catalog-50-50.yaml)

```bash
kubectl apply -f modules/06-traffic/solucao/virtualservice-catalog-90-10.yaml
for i in $(seq 1 20); do curl -s http://store.lab.test/item | python3 -c 'import json,sys; print(json.load(sys.stdin)["catalog"]["version"])'; done
```

Com 20 chamadas, 10% é cerca de duas respostas `v2`. Troque o arquivo para o 50/50 e repita. A proporção segue o peso, com folga de amostra pequena.

Para voltar ao estado da aula:

```bash
kubectl apply -k modules/06-traffic
```

## Perguntas

1. Por que o VirtualService do catalog não declara `gateways`?
2. O que o subset compara: a label do Pod ou o nome do Deployment?
3. Se a v2 cair para 0 réplicas com peso 50, o que o chamador recebe na metade das vezes?

## Limpeza

```bash
kubectl delete -k modules/06-traffic
```

Isso apaga o namespace `lab`. O Istio em `istio-system` permanece. No módulo 07 o mesmo `apply -k` sobe de novo.

## Respostas

1. Sem `gateways`, a regra vale na mesh: os sidecars dos clientes. O host `catalog.lab.svc.cluster.local` é interno. O gateway só entra no VirtualService da vitrine, que publica `store.lab.test`.
2. A label. O subset `v2` pega qualquer Pod com `version: v2` naquele host.
3. Falha nessa fração. Peso aponta para um subset vazio; o Envoy não improvisa outro subset.
