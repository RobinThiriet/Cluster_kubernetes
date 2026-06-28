# 06 - Runbook

## Etat general

    kubectl get nodes -o wide
    kubectl get pods -A
    kubectl get svc -A

## Cilium

    kubectl get pods -n kube-system -o wide | grep cilium
    kubectl -n kube-system rollout status ds/cilium
    kubectl -n kube-system rollout status deploy/cilium-operator

Logs :

    kubectl -n kube-system logs -l k8s-app=cilium --tail=100

## Local Path Provisioner

    kubectl get storageclass
    kubectl get pods -n local-path-storage -o wide

## MetalLB

    kubectl get pods -n metallb-system -o wide
    kubectl get ipaddresspool -n metallb-system
    kubectl get l2advertisement -n metallb-system
    kubectl get svc -A | grep LoadBalancer

Logs :

    kubectl -n metallb-system logs deploy/controller --tail=100
    kubectl -n metallb-system logs ds/speaker --tail=100

## Envoy Gateway

    kubectl get pods -n envoy-gateway-system -o wide
    kubectl get gatewayclass
    kubectl get gateway -A
    kubectl get httproute -A
    kubectl get svc -n envoy-gateway-system

Logs :

    kubectl -n envoy-gateway-system logs deploy/envoy-gateway --tail=100

## Gateway API

Lister les routes :

    kubectl get httproute -A

Decrire une route :

    kubectl describe httproute -n <namespace> <name>

Decrire la Gateway :

    kubectl describe gateway -n envoy-gateway-system eg

## Test DNS local

Avec une IP MetalLB, par exemple 192.168.1.200 :

    curl --resolve whoami.lab.local:80:192.168.1.200 http://whoami.lab.local/

## Probleme : LoadBalancer en Pending

Verifier MetalLB :

    kubectl get pods -n metallb-system
    kubectl get ipaddresspool -n metallb-system
    kubectl get l2advertisement -n metallb-system

Verifier que la plage IP est libre sur le LAN.

## Probleme : HTTPRoute non prise en compte

Verifier :

    kubectl describe httproute -A
    kubectl describe gateway -n envoy-gateway-system eg
    kubectl get gatewayclass

Verifier que :

- la GatewayClass existe ;
- la Gateway est acceptee ;
- le hostname de la route correspond a la Gateway ;
- le Service cible existe ;
- le port du Service est correct.
