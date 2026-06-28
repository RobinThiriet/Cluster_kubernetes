# 01 - Cilium

## Role

Cilium est le CNI du cluster Kubernetes.

Il permet :

- la communication entre pods ;
- la communication entre nodes ;
- les NetworkPolicies ;
- l'observabilite reseau avec Hubble si active.

Sans CNI, les nodes Kubernetes restent souvent en NotReady.

## Dossier

    00-cilium/
    ├── charts/
    ├── values/
    └── rendered/

## Commandes utilisees

Ajouter le repo Helm :

    helm repo add cilium https://helm.cilium.io --force-update
    helm repo update cilium

Voir les versions :

    helm search repo cilium/cilium --versions | head -n 10

Telecharger le chart :

    cd ~/kube-platform/00-cilium
    export CILIUM_VERSION="1.19.5"

    helm pull cilium/cilium \
      --version "$CILIUM_VERSION" \
      --untar \
      --untardir charts

Copier les values :

    cp charts/cilium/values.yaml values/cilium-default.yaml
    cp charts/cilium/values.yaml values/cilium.yaml

Generer le manifeste :

    helm template cilium charts/cilium \
      --namespace kube-system \
      --values values/cilium.yaml \
      --include-crds \
      > rendered/00-cilium.yaml

Dry-run :

    kubectl apply --server-side --dry-run=server -f rendered/00-cilium.yaml

Appliquer :

    kubectl apply --server-side -f rendered/00-cilium.yaml

## Verification

    kubectl get nodes
    kubectl get pods -n kube-system -o wide

Resultat attendu :

    control-plane   Ready
    node01          Ready
    node02          Ready

## Bonne pratique

Ne pas modifier directement :

    rendered/00-cilium.yaml

Modifier plutot :

    values/cilium.yaml

Puis regenerer avec helm template.
