# 03 - MetalLB

## Role

MetalLB fournit des IPs externes aux Services Kubernetes de type LoadBalancer.

Dans un cluster local ou bare-metal, Kubernetes ne sait pas attribuer seul une IP externe.

MetalLB fournit cette fonction.

## Dossier

    02-metallb/
    ├── upstream/
    ├── rendered/
    └── config/

## Commandes utilisees

Creer le dossier :

    cd ~/kube-platform
    mkdir -p 02-metallb/{upstream,rendered,config}
    cd 02-metallb

Telecharger le manifeste :

    export METALLB_VERSION="v0.16.1"

    curl -L \
      "https://raw.githubusercontent.com/metallb/metallb/${METALLB_VERSION}/config/manifests/metallb-native.yaml" \
      -o upstream/metallb-native.yaml

Copier le manifeste :

    cp upstream/metallb-native.yaml rendered/02-metallb.yaml

Appliquer :

    kubectl apply -f rendered/02-metallb.yaml

Verifier :

    kubectl -n metallb-system rollout status deploy/controller --timeout=3m
    kubectl -n metallb-system rollout status ds/speaker --timeout=3m
    kubectl get pods -n metallb-system -o wide

## Configuration IP

Fichier :

    02-metallb/config/metallb-pool.yaml

Contenu :

    apiVersion: metallb.io/v1beta1
    kind: IPAddressPool
    metadata:
      name: lan-pool
      namespace: metallb-system
    spec:
      addresses:
        - 192.168.1.200-192.168.1.210
    ---
    apiVersion: metallb.io/v1beta1
    kind: L2Advertisement
    metadata:
      name: lan-l2
      namespace: metallb-system
    spec:
      ipAddressPools:
        - lan-pool

Appliquer :

    kubectl apply --dry-run=server -f config/metallb-pool.yaml
    kubectl apply -f config/metallb-pool.yaml

Verifier :

    kubectl get ipaddresspool -n metallb-system
    kubectl get l2advertisement -n metallb-system

## Test realise

Creer un service nginx de test :

    kubectl create ns lb-test

    kubectl -n lb-test create deployment nginx \
      --image=nginx \
      --port=80

    kubectl -n lb-test expose deployment nginx \
      --type=LoadBalancer \
      --port=80 \
      --target-port=80

    kubectl -n lb-test get svc nginx -w

Tester :

    curl http://192.168.1.200

Nettoyer :

    kubectl delete ns lb-test

## Point important

La plage MetalLB doit etre libre sur le LAN et hors plage DHCP.
