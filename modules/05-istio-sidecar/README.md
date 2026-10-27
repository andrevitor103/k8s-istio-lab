# Módulo 05 — Istio sidecar

## Objetivo

Instalar o Istio, injetar o proxy no namespace `lab` e reconhecer o Envoy ao lado do processo. Os módulos seguintes escrevem regras; quem as executa é esse proxy.

## Conceitos

O Istio tem um control plane (`istiod`) e um proxy de dados. No modo sidecar, cada Pod do namespace rotulado ganha um Envoy (`istio-proxy`). O Envoy divide o network namespace com o app: iptables desvia o TCP de entrada e de saída para o proxy. O processo continua escutando na porta 8080. O proxy termina mTLS, aplica timeout, retry e a escolha de versão.

A label `istio-injection=enabled` marca o namespace. Ela vale para Pods criados depois. Deployment que já estava de pé precisa de um rollout.

Em releases recentes o proxy pode aparecer como init container nativo: ele sobe antes do app e permanece. `kubectl get pods` mostra `2/2` do mesmo jeito. O efeito operacional é o mesmo.

O perfil `demo` liga ingress gateway, egress gateway e telemetria de exemplo. Ele cabe neste laboratório. Num cluster de verdade o caminho é um perfil mínimo, com os componentes que você for usar.

Ambient mode é o outro jeito de instalar a mesh. Em vez de um Envoy dentro de cada Pod, um `ztunnel` por nó cuida de mTLS e identidade no L4. Política L7 (o VirtualService, o retry) sobe para um waypoint, só nos namespaces que pedem. Os objetos dos próximos módulos continuam válidos. Este lab fica no sidecar porque o proxy aparece na lista de containers e o efeito de cada YAML é direto de inspecionar.

## Antes de começar

O cluster está de pé e `make apps` já rodou. O módulo 03 ou 04 pode continuar aplicado: o rollout abaixo reinjeta esses Pods.

O perfil demo pede RAM. Se o nó começar a matar Pods com `OOMKilled`, feche outros programas antes de seguir.

## Passos

```bash
make istio-up
kubectl get pods -n istio-system
kubectl rollout restart deployment -n lab
kubectl rollout status deployment/catalog -n lab
kubectl rollout status deployment/storefront -n lab
```

Se o namespace `lab` ainda não tem os Deployments, aplique o módulo 03 antes do restart:

```bash
kubectl apply -k modules/03-dois-servicos
```

Compare um Pod de antes com o de agora. Se você não chegou a anotar, o próximo exercício cria um Pod sem a label.

```bash
kubectl get ns lab --show-labels
kubectl get pods -n lab
kubectl get pod -n lab -l app=catalog -o jsonpath='{range .items[*]}{.metadata.name}{"\n  containers: "}{.spec.containers[*].name}{"\n  init: "}{.spec.initContainers[*].name}{"\n"}{end}'
istioctl proxy-status
```

`proxy-status` lista os Envoys que sincronizaram com o istiod. Os Pods do catalog e do storefront aparecem aí.

O Ingress do módulo 04 pode continuar. O gateway do Istio ainda não ocupa a porta 80. Isso muda no módulo 06.

## O que observar

- `istio-system` tem `istiod` e `istio-ingressgateway` em `Running`. O Service do gateway fica com `EXTERNAL-IP` `<pending>`: o kind não entrega LoadBalancer. A publicação na porta 80 é o `make istio-gateway` do próximo módulo.
- Cada Pod de aplicação ganhou o `istio-proxy`.
- `curl http://store.lab.test/item` segue funcionando se o Ingress ainda está instalado. A malha está no caminho interno, transparente para essa chamada.

## Exercício

Crie um namespace sem a label de injeção, suba um Pod com a mesma imagem e compare os containers com um Pod de `lab`.

A referência dos comandos está em [solucao/comparar.sh](solucao/comparar.sh). Rode depois de escrever os seus:

```bash
bash modules/05-istio-sidecar/solucao/comparar.sh
```

O Pod de `fora` tem um container. O de `lab` tem o app e o proxy.

## Perguntas

1. A label de injeção altera um Pod que já estava `Running`?
2. O que o app enxerga de diferente na porta em que ele escuta?
3. Onde o ambient mode coloca o mTLS, já que ele dispensa o sidecar?

## Limpeza

O Istio fica instalado até o fim do lab. Para tirá-lo de uma vez:

```bash
make istio-down
```

Para repetir a comparação, apague só o namespace `fora` se o script não chegou nesse passo.

## Respostas

1. Não. A injeção acontece na criação do Pod. `kubectl rollout restart` cria Pods novos.
2. Nada na chamada local. O processo segue na 8080. Quem muda de lugar é o TCP que entra e sai do Pod: ele passa pelo Envoy.
3. No `ztunnel` do nó. Regras L7, quando existem, vão para um waypoint daquele namespace.
