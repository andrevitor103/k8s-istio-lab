# Módulo 00 — Ambiente

## Objetivo

Subir o cluster kind, apontar o kubectl para ele e criar o namespace `lab`, onde mora o resto do curso.

## Conceitos

Um cluster Kubernetes tem nós. O nó `control-plane` roda a API. Os nós `worker` rodam os seus Pods. O kind implementa cada nó como um container Docker.

O kubectl fala com o cluster indicado pelo contexto atual. O nome deste contexto é `kind-k8s-istio-lab`.

Um namespace agrupa recursos. Tudo que você aplicar daqui em diante fica em `lab`, separado de `kube-system` e, mais tarde, de `istio-system`.

## Antes de começar

Na raiz do lab:

```bash
export PATH="$HOME/.local/bin:$PATH"
make prereqs
```

Confira se as portas locais estão livres:

```bash
ss -ltnp | grep -E ':80 |:443 ' || true
```

Se aparecer um processo escutando, pare esse processo antes de criar o cluster. O kind precisa publicar 80 e 443 em `127.0.0.1`.

## Passos

```bash
make cluster-up
kubectl config current-context
kubectl get nodes -o wide --show-labels
kubectl apply -k modules/00-ambiente
kubectl get ns lab
```

`make cluster-up` é idempotente: se o cluster já existe, ele só seleciona o contexto.

Abra [cluster/kind-config.yaml](../../cluster/kind-config.yaml). A label `ingress-ready=true` marca o control-plane. O `extraPortMappings` liga a porta 80 desse nó à porta 80 da sua máquina. Os módulos 04 e 06 usam isso.

## O que observar

- Três nós `Ready`. Um tem o papel `control-plane`.
- A label `ingress-ready=true` está nesse nó.
- O control-plane com workers ao lado carrega o taint `node-role.kubernetes.io/control-plane:NoSchedule`. Pods sem toleration ficam nos workers. Por isso a aplicação não disputa CPU com a API.

## Exercício

Apague o namespace e recrie na mão, sem o kustomize. Compare o YAML que você escreveu com [namespace.yaml](namespace.yaml).

```bash
kubectl delete -k modules/00-ambiente
```

O arquivo de referência continua sendo `namespace.yaml`. Quando o seu YAML criar um namespace chamado `lab`, aplique de novo o do módulo:

```bash
kubectl apply -k modules/00-ambiente
```

## Perguntas

1. Por que o lab usa um contexto em vez de um endereço fixo no comando?
2. O que aconteceria com um Pod sem toleration se só existisse o control-plane?
3. Qual campo do kind-config faz `curl http://127.0.0.1` chegar, mais adiante, num controller dentro do cluster?

## Limpeza

```bash
kubectl delete -k modules/00-ambiente
```

Isso apaga o namespace `lab`. O cluster continua de pé. `make cluster-down` apaga o cluster.

## Respostas

1. O kubeconfig pode ter vários clusters. O contexto escolhe qual API receber o comando.
2. O kind tira o taint do control-plane quando ele é o único nó, e o Pod agenda ali. Com workers, o taint segura os Pods da aplicação fora da API.
3. `extraPortMappings`, no nó `control-plane`, com `containerPort: 80` e `hostPort: 80`.
