# Applications

Ce dossier contiendra les applications deployees sur le cluster.

## Convention proposee

Chaque application doit avoir son propre dossier :

    applications/
    └── whoami/
        ├── namespace.yaml
        ├── deployment.yaml
        ├── service.yaml
        └── httproute.yaml

## Regle

Une application doit etre exposee via :

    Gateway -> HTTPRoute -> Service -> Pods

Eviter d'exposer directement les applications avec NodePort.

## Exemples de noms DNS locaux

    whoami.lab.local
    grafana.lab.local
    api.lab.local
