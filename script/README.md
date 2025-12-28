# Kubernetes Bootstrap Script (kubeadm)

Ce script permet de **préparer et initialiser un cluster Kubernetes single-node**
à l’aide de **kubeadm**, prêt à être utilisé pour des workloads réels.

Il installe et configure automatiquement :
- containerd (runtime)
- kubeadm / kubelet / kubectl
- Calico (CNI)
- Helm
- Ingress NGINX (avec LoadBalancer cloud, ex: DigitalOcean)
- cert-manager
- ClusterIssuer Let’s Encrypt (HTTP-01)

 Le cluster obtenu est **prêt pour exposer des applications en HTTPS via Ingress**.

---

##  Philosophie

- ✅ Script **idempotent autant que possible**
- ✅ Pensé pour un **cluster de lab / dev / POC**
- ❌ Pas destiné à un cluster multi-nodes en production sans adaptation
- ❌ Ne gère pas la création de la VM ni le firewall cloud

---

##  Prérequis

### Système
- Ubuntu 22.04 (recommandé)
- Accès root (`sudo -i`)
- Accès Internet sortant

### Infrastructure
- VM / Droplet avec au minimum :
  - 2 vCPU
  - 4 Go RAM
- Firewall cloud ouvert sur :
  - `22/TCP` (SSH)
  - `80/TCP` (Ingress + Let's Encrypt)
  - `443/TCP` (HTTPS)
  - `6443/TCP` (API Kubernetes – optionnel)

### DNS (pour HTTPS)
- Un **nom de domaine PUBLIC**
- Un enregistrement DNS `A` pointant vers l’IP du LoadBalancer Ingress
  (configuré après l’exécution du script)

---

##  Utilisation

###  Se connecter à la machine
```bash
ssh user@<ip>
sudo -i
