ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
export PATH := $(HOME)/.local/bin:$(PATH)

CLUSTER ?= k8s-istio-lab
KIND_CONFIG := $(ROOT)/cluster/kind-config.yaml

.DEFAULT_GOAL := help

.PHONY: help prereqs cluster-up cluster-down apps ingress-nginx istio-up istio-gateway istio-down observability observability-down

help:
	@printf '%s\n' \
		'prereqs              instala kubectl, kind, helm e istioctl se faltarem' \
		'cluster-up           cria o cluster kind ($(CLUSTER))' \
		'cluster-down         apaga o cluster kind' \
		'apps                 build das imagens e kind load' \
		'ingress-nginx        instala o ingress-nginx (módulo 04)' \
		'istio-up             instala o Istio no perfil demo' \
		'istio-gateway        publica o gateway em 127.0.0.1:80 (módulo 06)' \
		'istio-down           remove o Istio' \
		'observability        instala Kiali, Prometheus e Jaeger' \
		'observability-down   remove esses addons'

prereqs:
	bash $(ROOT)/scripts/check-prereqs.sh

cluster-up: prereqs
	@if kind get clusters 2>/dev/null | grep -qx '$(CLUSTER)'; then \
		echo 'Cluster $(CLUSTER) já existe.'; \
	else \
		kind create cluster --name $(CLUSTER) --config $(KIND_CONFIG); \
	fi
	kubectl config use-context kind-$(CLUSTER)
	kubectl get nodes

cluster-down:
	kind delete cluster --name $(CLUSTER)

apps:
	docker build -t catalog:lab $(ROOT)/app/catalog
	docker build -t storefront:lab $(ROOT)/app/storefront
	kind load docker-image catalog:lab --name $(CLUSTER)
	kind load docker-image storefront:lab --name $(CLUSTER)

ingress-nginx:
	bash $(ROOT)/scripts/install-ingress-nginx.sh

istio-up: prereqs
	istioctl install --set profile=demo -y
	kubectl create namespace lab --dry-run=client -o yaml | kubectl apply -f -
	kubectl label namespace lab istio-injection=enabled --overwrite
	@echo 'Para Pods que já existiam, reinicie os Deployments:'
	@echo '  kubectl rollout restart deployment -n lab'

istio-gateway:
	python3 $(ROOT)/scripts/expose-istio-gateway.py

istio-down:
	istioctl uninstall --purge -y
	kubectl delete namespace istio-system --ignore-not-found

observability:
	bash $(ROOT)/scripts/install-observability.sh

observability-down:
	bash $(ROOT)/scripts/install-observability.sh --delete
