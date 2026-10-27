# Módulo 04 — Ingress

## Objetivo

Publicar o storefront em `http://store.lab.test` na sua máquina. Este é o limite do que o Ingress faz sozinho: escolher um Service de entrada pelo host e pelo path.

## Conceitos

O Ingress é uma regra. Quem a cumpre é um controller. Aqui o controller é o ingress-nginx, instalado com Helm.

No kind, o controller usa a rede do nó (`hostNetwork`) e só agenda no nó com a label `ingress-ready`. Esse nó é o control-plane, o mesmo que tem `extraPortMappings` para as portas 80 e 443. O arquivo [cluster/ingress-nginx-values.yaml](../../cluster/ingress-nginx-values.yaml) é essa combinação.

`ingressClassName: nginx` entrega o objeto a esse controller. O host `store.lab.test` só existe na sua máquina: uma linha em `/etc/hosts` aponta o nome para `127.0.0.1`.

O Ingress chega até o Service. Ele não vê a chamada do storefront para o catalog, não divide tráfego entre versões e não impõe timeout nessa chamada interna. Esse é o buraco que a mesh fecha a partir do módulo 05.

A API sucessora do Ingress no Kubernetes é a Gateway API (`Gateway` e `HTTPRoute`). O Istio também a implementa. O módulo 06 usa `Gateway` e `VirtualService` do próprio Istio, que é o vocabulário dos exercícios de tráfego. A Gateway API fica para um ciclo seguinte, para este lab ter um modelo de entrada de cada vez.

## Antes de começar

```bash
make apps
make ingress-nginx
```

O Helm espera o Deployment do controller ficar pronto. Se o `kubectl apply` do Ingress reclamar do webhook de admissão, espere uns segundos e aplique de novo: o certificado do webhook é gerado no primeiro boot.

## Passos

```bash
grep -q 'store.lab.test' /etc/hosts || echo '127.0.0.1 store.lab.test' | sudo tee -a /etc/hosts
kubectl apply -k modules/04-ingress
kubectl rollout status deployment/catalog -n lab
kubectl rollout status deployment/storefront -n lab
kubectl get ingress -n lab
curl -s http://store.lab.test/item
```

O JSON é o mesmo do port-forward. O caminho agora é o da porta 80.

## O que observar

- `kubectl get pods -n ingress-nginx -o wide` mostra o controller no nó de control-plane.
- `kubectl describe ingress storefront -n lab` mostra a class e o backend.
- `curl http://store.lab.test/items/1` ainda cai no storefront, porque a única regra é o prefixo `/`. O exercício muda isso.

## Exercício

Acrescente um path `/items` com o mesmo host, apontando para o Service `catalog` na porta 8080. O prefixo mais específico fica com o catalog; `/item` continua no storefront.

A referência está em [solucao/ingress.yaml](solucao/ingress.yaml).

```bash
kubectl apply -f modules/04-ingress/solucao/ingress.yaml
curl -s http://store.lab.test/items/1
curl -s http://store.lab.test/item
```

A primeira resposta é o catalog cru (`version` na raiz do JSON). A segunda é o storefront, com `catalog` aninhado.

## Perguntas

1. O que o Ingress sabe sobre a chamada HTTP que o storefront faz ao catalog?
2. Por que o controller precisa da label `ingress-ready` neste kind, e não basta um Service `LoadBalancer`?
3. Qual objeto você vai trocar no módulo 06 para a mesma URL continuar abrindo?

## Limpeza

O módulo 06 precisa da porta 80 livre. Quando for instalar o gateway do Istio, apague os dois:

```bash
kubectl delete -k modules/04-ingress
kubectl delete namespace ingress-nginx --wait
```

Enquanto você ainda está neste módulo, pode deixar o controller instalado.

## Respostas

1. Nada. Essa chamada usa o ClusterIP, dentro do cluster. O Ingress só vê o pedido que chegou no host `store.lab.test`.
2. O kind deste lab não tem um balanceador externo. O `extraPortMappings` só alcança o nó de control-plane, então o controller tem de escutar a porta 80 ali.
3. O `Gateway` e o `VirtualService` do Istio passam a receber `store.lab.test`. O objeto Ingress sai.
