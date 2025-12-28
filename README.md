# Cluster_kubernetes

---

#  Créer un cluster Kubernetes propre – Guide pas à pas

Ce guide permet de **recréer intégralement un cluster Kubernetes fonctionnel**, prêt pour la production, avec :

* kubeadm
* Ingress NGINX
* LoadBalancer DigitalOcean
* cert-manager
* HTTPS Let’s Encrypt
* Déploiement applicatif (exemple : Uptime Kuma)

---

##  Étape 0 — Préparer l’infrastructure

### 0.1 Créer une VM / Droplet

* Ubuntu 22.04 recommandé
* 2 vCPU minimum
* 4 Go RAM minimum

### 0.2 Firewall cloud (OBLIGATOIRE)

Ouvrir les ports suivants :

* `22/TCP` → SSH
* `80/TCP` → HTTP (Ingress + Let’s Encrypt)
* `443/TCP` → HTTPS
* `6443/TCP` → API Kubernetes (optionnel, selon usage)

---

##  Étape 1 — Installer Kubernetes (kubeadm)

 Cette étape est **volontairement manuelle** pour comprendre ce que l’on fait.

### 1.1 Désactiver le swap

```bash
sudo swapoff -a
sudo sed -i '/ swap / s/^/#/' /etc/fstab
```

### 1.2 Installer containerd

```bash
sudo apt update
sudo apt install -y containerd
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
sudo systemctl restart containerd
sudo systemctl enable containerd
```

### 1.3 Installer kubeadm / kubelet / kubectl

```bash
sudo apt install -y apt-transport-https ca-certificates curl
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes.gpg

echo "deb [signed-by=/etc/apt/keyrings/kubernetes.gpg] https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt update
sudo apt install -y kubeadm kubelet kubectl
sudo apt-mark hold kubeadm kubelet kubectl
```

### 1.4 Initialiser le cluster

```bash
sudo kubeadm init
```

Configurer kubectl :

```bash
mkdir -p ~/.kube
sudo cp /etc/kubernetes/admin.conf ~/.kube/config
sudo chown $(id -u):$(id -g) ~/.kube/config
```

---

##  Étape 2 — Installer le réseau (CNI)

### 2.1 Installer Calico

```bash
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/master/manifests/calico.yaml
```

### 2.2 Single-node : enlever le taint control-plane

```bash
kubectl taint nodes --all node-role.kubernetes.io/control-plane-
```

Vérification :

```bash
kubectl get nodes
```

---

##  Étape 3 — Installer Ingress NGINX (avec LoadBalancer)

 Cette étape crée **automatiquement un LoadBalancer DigitalOcean**.

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.11.1/deploy/static/provider/cloud/deploy.yaml
```

Attendre :

```bash
kubectl get svc -n ingress-nginx
```

 Noter l’`EXTERNAL-IP` du service `ingress-nginx-controller`

---

##  Étape 4 — Configurer le DNS

Créer un enregistrement DNS :

```
kuma.example.com → <EXTERNAL-IP du ingress-nginx-controller>
```

 Obligatoire pour Let’s Encrypt.

---

##  Étape 5 — Installer cert-manager

```bash
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.16.3/cert-manager.yaml
```

Vérifier :

```bash
kubectl get pods -n cert-manager
```

---

##  Étape 6 — Créer le ClusterIssuer Let’s Encrypt

```bash
kubectl apply -f 02-cert-manager/clusterissuer-letsencrypt.yaml
```

Vérifier :

```bash
kubectl get clusterissuer
```

---

##  Étape 7 — Déployer une application (exemple : Uptime Kuma)

```bash
kubectl apply -f 03-apps/uptime-kuma/namespace.yaml
kubectl apply -f 03-apps/uptime-kuma/pvc.yaml
kubectl apply -f 03-apps/uptime-kuma/deployment.yaml
kubectl apply -f 03-apps/uptime-kuma/service.yaml
kubectl apply -f 03-apps/uptime-kuma/ingress.yaml
```

---

##  Étape 8 — Vérifications finales

```bash
kubectl get pods -n monitoring
kubectl get ingress -n monitoring
kubectl get certificate -n monitoring
```

Quand le certificat est prêt :

```
https://kuma.example.com
```

---

##  Ce que ce repo permet

✔ Recréer un cluster Kubernetes from scratch
✔ Comprendre chaque couche
✔ Architecture cloud propre
✔ HTTPS automatique
✔ Base solide pour production
✔ Excellent support d’apprentissage

---



👉 Dis-moi, je t’aide à le rendre encore plus pro 🚀
