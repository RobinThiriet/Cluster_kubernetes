# Cluster Kubernetes

Plateforme Kubernetes locale.

## Composants

- Cilium : CNI réseau
- local-path-provisioner : stockage local
- MetalLB : LoadBalancer local
- Envoy Gateway : Gateway API / entrée HTTP

## Réseau

- Nodes : 192.168.1.100-102
- MetalLB pool : 192.168.1.200-192.168.1.210

## Ordre d'installation

1. 00-cilium
2. 01-local-path-provisioner
3. 02-metallb
4. 03-envoy-gateway
5. apps
