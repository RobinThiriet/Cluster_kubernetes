# 02 - Local Path Provisioner

## Role

Local Path Provisioner fournit une StorageClass locale.

Il permet aux applications de creer des volumes avec des PersistentVolumeClaim.

## Dossier

    01-local-path-provisioner/
    ├── upstream/
    └── rendered/

## Commandes utilisees

Creer le dossier :

    cd ~/kube-platform
    mkdir -p 01-local-path-provisioner/{upstream,rendered}
    cd 01-local-path-provisioner

Telecharger le manifeste :

    export LOCAL_PATH_VERSION="v0.0.36"

    curl -L \
      "https://raw.githubusercontent.com/rancher/local-path-provisioner/${LOCAL_PATH_VERSION}/deploy/local-path-storage.yaml" \
      -o upstream/local-path-storage.yaml

Copier le manifeste :

    cp upstream/local-path-storage.yaml rendered/01-local-path-provisioner.yaml

Creer le namespace :

    kubectl apply -f <(awk 'BEGIN{RS="---"} /kind: Namespace/ {print}' rendered/01-local-path-provisioner.yaml)

Dry-run :

    kubectl apply --dry-run=server -f rendered/01-local-path-provisioner.yaml

Appliquer :

    kubectl apply -f rendered/01-local-path-provisioner.yaml

Mettre en StorageClass par defaut :

    kubectl patch storageclass local-path \
      -p '{"metadata":{"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'

## Verification

    kubectl get storageclass
    kubectl get pods -n local-path-storage -o wide

Resultat attendu :

    local-path (default)
    local-path-provisioner   1/1 Running

## Limite

Ce stockage est local au node.

Si un volume est cree sur node01, il depend de node01.

Pour de la production, on utiliserait plutot :

- Longhorn
- Rook/Ceph
- NFS
- CSI cloud provider
- SAN/NAS
