# 07 - KubeView

## Role

KubeView est une application de visualisation du cluster Kubernetes.

Elle permet d'afficher graphiquement les ressources du cluster :

- namespaces ;
- pods ;
- services ;
- deployments ;
- relations entre ressources Kubernetes.

Dans ce cluster, KubeView est installe comme une application interne, puis expose via Envoy Gateway et Gateway API.

## Architecture

    Client
       |
       v
    kubeview.lab.local
       |
       v
    Envoy Gateway
       |
       v
    HTTPRoute
       |
       v
    Service kubeview ClusterIP
       |
       v
    Pod kubeview

## Dossier

    applications/kubeview/
    ├── charts/
    ├── values/
    ├── rendered/
    └── config/

## Principe d'installation

KubeView est installe via Helm, mais selon la methode utilisee pour le reste du cluster :

1. telecharger le chart Helm en local ;
2. sauvegarder les values par defaut ;
3. creer un fichier values personnalise ;
4. generer un manifeste avec helm template ;
5. appliquer le manifeste avec kubectl ;
6. exposer l'application via HTTPRoute.

## Commandes utilisees

### Creation du dossier

    cd ~/kube-platform
    mkdir -p applications/kubeview/{charts,values,rendered,config}
    cd applications/kubeview

### Ajout du repository Helm

    helm repo add kubeview https://code.benco.io/kubeview/deploy/helm --force-update
    helm repo update kubeview

### Verification des versions

    helm search repo kubeview/kubeview --versions | head -n 10

### Telechargement du chart

    export KUBEVIEW_VERSION="2.0.6"

    helm pull kubeview/kubeview \
      --version "$KUBEVIEW_VERSION" \
      --untar \
      --untardir charts

### Copie des values

    cp charts/kubeview/values.yaml values/kubeview-default.yaml
    cp charts/kubeview/values.yaml values/kubeview.yaml

Le fichier `values/kubeview-default.yaml` sert de reference.

Le fichier `values/kubeview.yaml` est le fichier modifiable.

## Configuration retenue

Le Service KubeView doit rester interne au cluster.

On ne veut pas exposer KubeView directement avec un Service LoadBalancer, car l'exposition doit passer par Envoy Gateway.

Fichier :

    applications/kubeview/values/kubeview.yaml

Contenu retenu :

    replicaCount: 1

    singleNamespace: false

    service:
      type: ClusterIP
      externalPort: 8000
      internalPort: 8000

    ingress:
      enabled: false

    resources:
      requests:
        cpu: 50m
        memory: 64Mi
      limits:
        cpu: 100m
        memory: 128Mi

## Generation du manifeste

    helm template kubeview charts/kubeview \
      --namespace kubeview \
      --values values/kubeview.yaml \
      > rendered/kubeview.yaml

## Creation du namespace

    kubectl create namespace kubeview --dry-run=client -o yaml | kubectl apply -f -

## Dry-run

    kubectl apply --dry-run=server -n kubeview -f rendered/kubeview.yaml

## Application

    kubectl apply -n kubeview -f rendered/kubeview.yaml

## Verification

    kubectl -n kubeview get pods -o wide
    kubectl -n kubeview get svc
    kubectl -n kubeview rollout status deploy/kubeview --timeout=3m

Resultat attendu :

    deployment.apps/kubeview   1/1
    service/kubeview           ClusterIP   8000/TCP

## Correction realisee

Pendant l'installation, KubeView a ete applique une premiere fois dans le namespace `default`.

Les ressources applicatives ont ete supprimees de `default` :

    kubectl -n default delete deployment kubeview --ignore-not-found
    kubectl -n default delete service kubeview --ignore-not-found
    kubectl -n default delete serviceaccount kubeview --ignore-not-found

Puis le manifeste a ete applique explicitement dans le namespace `kubeview` :

    kubectl apply -n kubeview -f rendered/kubeview.yaml

## HTTPRoute

KubeView est expose via Gateway API.

Fichier :

    applications/kubeview/config/httproute.yaml

Contenu :

    apiVersion: gateway.networking.k8s.io/v1
    kind: HTTPRoute
    metadata:
      name: kubeview
      namespace: kubeview
    spec:
      parentRefs:
        - name: eg
          namespace: envoy-gateway-system
      hostnames:
        - kubeview.lab.local
      rules:
        - backendRefs:
            - name: kubeview
              port: 8000

Application :

    kubectl apply --dry-run=server -f config/httproute.yaml
    kubectl apply -f config/httproute.yaml

Verification :

    kubectl get httproute -n kubeview
    kubectl describe httproute -n kubeview kubeview

## Test d'acces

Recuperer l'IP du Service Envoy Gateway :

    kubectl get svc -n envoy-gateway-system

Tester sans DNS local :

    curl --resolve kubeview.lab.local:80:192.168.1.200 http://kubeview.lab.local/

Ou ajouter dans le fichier hosts du poste client :

    192.168.1.200 kubeview.lab.local

Puis ouvrir :

    http://kubeview.lab.local

## Bonnes pratiques

KubeView ne doit pas avoir son propre Service LoadBalancer.

Le modele correct est :

    Envoy Gateway -> HTTPRoute -> Service ClusterIP -> Pod

Cela permet de garder un point d'entree unique pour les applications du cluster.