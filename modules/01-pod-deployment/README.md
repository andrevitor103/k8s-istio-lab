# Módulo 01 — Pod e Deployment

## Objetivo

Rodar o catalog como um Pod solto e depois trocar esse Pod por um Deployment com duas réplicas. No fim você sabe quem recria o processo quando ele morre.

## Conceitos

Um Pod é o menor objeto que o Kubernetes agenda. Ele tem um IP, uma rede e um ou mais containers. Esse IP muda quando o Pod é recriado.

Um Deployment declara quantas réplicas você quer e qual template de Pod usar. Ele cria um ReplicaSet, e o ReplicaSet segura a contagem. Você muda o template; o Deployment troca os Pods aos poucos. Isso é o rollout.

Labels são pares chave/valor. O `selector` do Deployment precisa continuar batendo com as labels do template. Se o selector mudar, o objeto é outro Deployment.

`requests` reservam CPU e memória no nó. `limits.memory` corta o container se ele passar do teto.

## Antes de começar

O namespace `lab` existe (módulo 00) e as imagens já foram carregadas no kind:

```bash
make apps
```

`imagePullPolicy: IfNotPresent` usa a imagem `catalog:lab` que o `kind load` colocou nos nós. Sem esse passo o Pod fica em `ImagePullBackOff`.

## Passos

Aplique o Pod solto:

```bash
kubectl apply -k modules/01-pod-deployment/pod
kubectl get pod -n lab -o wide
kubectl describe pod -n lab catalog
kubectl logs -n lab catalog
kubectl exec -n lab catalog -- python -c 'import urllib.request; print(urllib.request.urlopen("http://127.0.0.1:8080/items/1").read().decode())'
```

Apague o container por dentro do nó e veja o Pod sumir de vez:

```bash
kubectl delete pod -n lab catalog
kubectl get pod -n lab
```

Nada recria esse Pod. Agora troque pelo Deployment. Apague o Pod antes, se ele ainda existir: os dois usam a label `app=catalog` e, no próximo módulo, os dois entrariam no mesmo Service.

```bash
kubectl delete pod -n lab catalog --ignore-not-found
kubectl apply -k modules/01-pod-deployment
kubectl rollout status deployment/catalog -n lab
kubectl get pods -n lab -o wide
kubectl get replicaset -n lab
```

Derrube um Pod gerado pelo Deployment:

```bash
kubectl delete pod -n lab -l app=catalog --wait=false
kubectl get pods -n lab -w
```

`Ctrl+C` sai do watch. A contagem volta para 2. O nome do Pod novo é outro.

Veja o histórico e o template:

```bash
kubectl rollout history deployment/catalog -n lab
kubectl explain deployment.spec.replicas
```

## O que observar

- O Pod solto tem o nome que você escreveu (`catalog`). Os Pods do Deployment ganham um sufixo do ReplicaSet.
- `describe` mostra a imagem, o nó, os eventos e o motivo de um eventual `Pending` ou `CrashLoopBackOff`.
- Depois do `delete`, o ReplicaSet cria outro Pod. O IP desse Pod é diferente.
- `requests` aparecem no `describe`, na seção de recursos do container.

## Exercício

Altere o Deployment para 3 réplicas e acrescente a label `track=stable` no template do Pod. Mantenha o `selector` como está (`app: catalog`).

Aplique a sua alteração e confira:

```bash
kubectl get pods -n lab --show-labels
kubectl get deploy catalog -n lab
```

A referência está em [solucao/deployment.yaml](solucao/deployment.yaml). Para ver o efeito dela no cluster:

```bash
kubectl apply -k modules/01-pod-deployment/solucao
```

A label nova fica no Pod. Ela fica fora do `selector`. Colocar `track` no selector exigiria um Deployment novo, porque o selector é imutável.

## Perguntas

1. Quem cria o Pod quando você aplica um Deployment?
2. Por que o IP do Pod é um mau endereço para outro serviço guardar?
3. O que o ReplicaSet compara para decidir se precisa de mais um Pod?

## Limpeza

```bash
kubectl delete -k modules/01-pod-deployment
kubectl delete -k modules/01-pod-deployment/pod --ignore-not-found
```

O primeiro comando apaga o namespace `lab` e, com ele, o Deployment. Recrie o namespace no próximo módulo com `kubectl apply -k`, que inclui o namespace de novo.

## Respostas

1. O ReplicaSet dono da revisão atual. O Deployment só declara a revisão e a estratégia de troca.
2. O IP morre junto com o Pod. O módulo 02 coloca um Service na frente.
3. As labels do `selector` contra as labels dos Pods, e a contagem em `replicas`.
