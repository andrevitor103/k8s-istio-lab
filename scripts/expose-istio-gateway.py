#!/usr/bin/env python3
"""Publica o Istio ingress gateway na porta 80 do nó de control-plane do kind.

O extraPortMappings do cluster encaminha 127.0.0.1:80 até a porta 80 desse nó.
O Envoy do gateway escuta em 8080; o hostPort liga a porta 80 do nó a essa porta.
"""

import json
import subprocess
import sys

WANTED_TOLERATION = {
    "key": "node-role.kubernetes.io/control-plane",
    "operator": "Exists",
    "effect": "NoSchedule",
}
HOST_FOR = {8080: 80, 8443: 443}


def kubectl(*args, input_text=None):
    result = subprocess.run(
        ["kubectl", *args],
        input=input_text,
        text=True,
        capture_output=True,
    )
    if result.returncode != 0:
        sys.stderr.write(result.stderr or result.stdout)
        raise SystemExit(result.returncode)
    return result.stdout


def main():
    namespaces = json.loads(kubectl("get", "ns", "-o", "json"))
    names = {item["metadata"]["name"] for item in namespaces["items"]}
    if "ingress-nginx" in names:
        sys.stderr.write(
            "O namespace ingress-nginx ainda existe e segura a porta 80 do nó.\n"
            "Apague o Ingress do módulo 04 e o controller antes do gateway:\n"
            "  kubectl delete -k modules/04-ingress\n"
            "  kubectl delete namespace ingress-nginx --wait\n"
        )
        raise SystemExit(1)

    dep = json.loads(
        kubectl(
            "get",
            "deploy",
            "-n",
            "istio-system",
            "istio-ingressgateway",
            "-o",
            "json",
        )
    )
    pod_spec = dep["spec"]["template"]["spec"]
    containers = pod_spec["containers"]
    proxy_index = next(
        index for index, container in enumerate(containers) if container["name"] == "istio-proxy"
    )
    ops = []

    node_selector = pod_spec.get("nodeSelector")
    if not node_selector:
        ops.append(
            {
                "op": "add",
                "path": "/spec/template/spec/nodeSelector",
                "value": {"ingress-ready": "true"},
            }
        )
    elif node_selector.get("ingress-ready") != "true":
        ops.append(
            {
                "op": "add",
                "path": "/spec/template/spec/nodeSelector/ingress-ready",
                "value": "true",
            }
        )

    tolerations = pod_spec.get("tolerations")
    has_toleration = any(
        item.get("key") == WANTED_TOLERATION["key"] and item.get("effect") == "NoSchedule"
        for item in (tolerations or [])
    )
    if not tolerations:
        ops.append(
            {
                "op": "add",
                "path": "/spec/template/spec/tolerations",
                "value": [WANTED_TOLERATION],
            }
        )
    elif not has_toleration:
        ops.append(
            {
                "op": "add",
                "path": "/spec/template/spec/tolerations/-",
                "value": WANTED_TOLERATION,
            }
        )

    for index, port in enumerate(containers[proxy_index].get("ports", [])):
        container_port = port.get("containerPort")
        host_port = HOST_FOR.get(container_port)
        if host_port is not None and port.get("hostPort") != host_port:
            ops.append(
                {
                    "op": "add",
                    "path": (
                        f"/spec/template/spec/containers/{proxy_index}"
                        f"/ports/{index}/hostPort"
                    ),
                    "value": host_port,
                }
            )

    if dep["spec"].get("replicas") != 1:
        ops.append({"op": "replace", "path": "/spec/replicas", "value": 1})

    if ops:
        kubectl(
            "patch",
            "deploy",
            "-n",
            "istio-system",
            "istio-ingressgateway",
            "--type=json",
            "-p",
            json.dumps(ops),
        )
    else:
        print("O gateway já estava com hostPort 80/443 no control-plane.")

    hpas = kubectl("get", "hpa", "-n", "istio-system", "-o", "name")
    if "horizontalpodautoscaler.autoscaling/istio-ingressgateway" in hpas or any(
        line.endswith("istio-ingressgateway") for line in hpas.splitlines()
    ):
        kubectl(
            "patch",
            "hpa",
            "-n",
            "istio-system",
            "istio-ingressgateway",
            "--type=merge",
            "-p",
            json.dumps({"spec": {"minReplicas": 1, "maxReplicas": 1}}),
        )

    kubectl(
        "rollout",
        "status",
        "-n",
        "istio-system",
        "deploy/istio-ingressgateway",
        "--timeout=180s",
    )
    print("Gateway disponível em http://store.lab.test (127.0.0.1:80).")


if __name__ == "__main__":
    main()
