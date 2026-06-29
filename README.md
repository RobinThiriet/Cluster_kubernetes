# Cluster Kubernetes local

Ce depot contient la configuration d'un cluster Kubernetes local construit manuellement.

L'objectif est d'avoir une base propre, documentee et versionnee avant de deployer des applications.

## Composants installes

- Cilium : reseau Kubernetes
- Local Path Provisioner : stockage dynamique local
- MetalLB : LoadBalancer local
- Envoy Gateway : point d'entree HTTP avec Gateway API

## Architecture

    Client LAN
       |
       v
    IP MetalLB 192.168.1.200-192.168.1.210
       |
       v
    Envoy Gateway
       |
       v
    HTTPRoute
       |
       v
    Service Kubernetes
       |
       v
    Pods applicatifs

## Documentation

La documentation detaillee est dans le dossier :

    documentation/

Ordre de lecture conseille :

1. documentation/00-vue-ensemble.md
2. documentation/01-cilium.md
3. documentation/02-local-path-provisioner.md
4. documentation/03-metallb.md
5. documentation/04-envoy-gateway.md
6. documentation/05-git-workflow.md
7. documentation/06-runbook.md

## Arborescence

    .
    ├── 00-cilium/
    ├── 01-local-path-provisioner/
    ├── 02-metallb/
    ├── 03-envoy-gateway/
    ├── applications/
    └── documentation/

## Etat actuel

- [x] Cilium
- [x] Local Path Provisioner
- [x] MetalLB
- [x] Envoy Gateway
- [ ] Applications

## Branche de travail conseillee

La branche main contient le socle stable.

Pour tester des applications :

    git checkout -b applications/poc

## Teleport

Documentation Teleport :

- [Teleport](documentation/08-teleport.md)

Teleport est actuellement valide pour :

- acces Web ;
- creation d'un utilisateur local ;
- enrolement d'un agent Linux ;
- connexion SSH via Teleport.

La suite prevue :

- service systemd pour les agents ;
- deploiement Ansible ;
- test Windows Server ;
- SSO Keycloak ;
- Vault pour les secrets.
