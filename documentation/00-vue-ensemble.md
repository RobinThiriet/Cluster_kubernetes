# 00 - Vue d'ensemble

## Objectif

Ce cluster Kubernetes local sert de socle de test avant le deploiement d'applications.

Objectifs :

- avoir un reseau Kubernetes fonctionnel ;
- avoir du stockage dynamique ;
- avoir des IP LoadBalancer locales ;
- avoir un point d'entree HTTP unique ;
- versionner toute la configuration dans Git.

## Nodes

| Node | Role | IP |
|---|---|---|
| control-plane | Control plane | 192.168.1.100 |
| node01 | Worker | 192.168.1.101 |
| node02 | Worker | 192.168.1.102 |

## Plage MetalLB

    192.168.1.200-192.168.1.210

Cette plage est reservee aux Services Kubernetes de type LoadBalancer.

## Couches installees

| Couche | Composant | Role |
|---|---|---|
| Reseau | Cilium | CNI du cluster |
| Stockage | Local Path Provisioner | Volumes locaux dynamiques |
| LoadBalancer | MetalLB | IPs externes locales |
| Gateway | Envoy Gateway | Routage HTTP avec Gateway API |

## Flux cible

    Client LAN
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
    Service Kubernetes
       |
       v
    Pod applicatif

## Dossiers principaux

    00-cilium/
    01-local-path-provisioner/
    02-metallb/
    03-envoy-gateway/
    applications/
    documentation/
