# Documentation du cluster

Ce dossier contient la documentation technique du cluster.

## Documents

| Fichier | Description |
|---|---|
| 00-vue-ensemble.md | Vue globale de l'architecture |
| 01-cilium.md | Reseau Kubernetes avec Cilium |
| 02-local-path-provisioner.md | Stockage dynamique local |
| 03-metallb.md | LoadBalancer local avec MetalLB |
| 04-envoy-gateway.md | Exposition HTTP avec Gateway API |
| 05-git-workflow.md | Methode de travail Git |
| 06-runbook.md | Commandes utiles de verification et diagnostic |

## Regle principale

Le depot Git doit devenir la source de verite.

On ne modifie pas directement un manifeste genere par Helm dans rendered/ si ce manifeste vient d'un chart.

On modifie plutot :

- values/*.yaml
- config/*.yaml

Puis on regenere le manifeste.
