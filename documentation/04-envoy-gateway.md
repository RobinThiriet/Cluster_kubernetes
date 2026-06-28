# 04 - Envoy Gateway

## Role

Envoy Gateway est le controleur Gateway API.

Il permet d'exposer les applications avec :

- GatewayClass
- Gateway
- HTTPRoute

Envoy Gateway observe les objets Gateway API et cree les ressources Envoy necessaires.

## Dossier

    03-envoy-gateway/
    ├── charts/
    ├── values/
    ├── rendered/
    └── config/

## Commandes utilisees

Creer le dossier :

    cd ~/kube-platform
    mkdir -p 03-envoy-gateway/{charts,values,rendered,config}
    cd 03-envoy-gateway

Verifier le chart OCI :

    export ENVOY_GATEWAY_VERSION="v1.4.4"

    helm show chart oci://docker.io/envoyproxy/gateway-helm \
      --version "$ENVOY_GATEWAY_VERSION"

Telecharger le chart :

    helm pull oci://docker.io/envoyproxy/gateway-helm \
      --version "$ENVOY_GATEWAY_VERSION" \
      --untar \
      --untardir charts

Copier les values :

    cp charts/gateway-helm/values.yaml values/envoy-default.yaml
    cp charts/gateway-helm/values.yaml values/envoy.yaml

Generer le manifeste :

    helm template eg charts/gateway-helm \
      --namespace envoy-gateway-system \
      --values values/envoy.yaml \
      --include-crds \
      > rendered/03-envoy-gateway.yaml

Creer le namespace :

    kubectl create namespace envoy-gateway-system --dry-run=client -o yaml | kubectl apply -f -

Dry-run :

    kubectl apply --server-side --dry-run=server -f rendered/03-envoy-gateway.yaml

Appliquer :

    kubectl apply --server-side -f rendered/03-envoy-gateway.yaml

Verifier :

    kubectl -n envoy-gateway-system rollout status deploy/envoy-gateway --timeout=3m
    kubectl get pods -n envoy-gateway-system -o wide
    kubectl get crd | grep gateway.networking.k8s.io

## GatewayClass et Gateway

Fichier :

    03-envoy-gateway/config/gateway.yaml

Contenu :

    apiVersion: gateway.networking.k8s.io/v1
    kind: GatewayClass
    metadata:
      name: eg
    spec:
      controllerName: gateway.envoyproxy.io/gatewayclass-controller
    ---
    apiVersion: gateway.networking.k8s.io/v1
    kind: Gateway
    metadata:
      name: eg
      namespace: envoy-gateway-system
    spec:
      gatewayClassName: eg
      listeners:
        - name: http
          protocol: HTTP
          port: 80
          hostname: "*.lab.local"
          allowedRoutes:
            namespaces:
              from: All

Appliquer :

    kubectl apply --dry-run=server -f config/gateway.yaml
    kubectl apply -f config/gateway.yaml

Verifier :

    kubectl get gatewayclass
    kubectl get gateway -n envoy-gateway-system
    kubectl get svc -n envoy-gateway-system

## Flux logique

    Client
       |
       v
    IP MetalLB
       |
       v
    Service LoadBalancer Envoy
       |
       v
    Pod Envoy
       |
       v
    HTTPRoute
       |
       v
    Service applicatif
       |
       v
    Pod applicatif
