#!/bin/bash
set -euo pipefail

echo "====================================="
echo "  🚀 Setup Kubernetes single-node (kubeadm)"
echo "====================================="
sleep 1

if [ "$(id -u)" -ne 0 ]; then
  echo "Ce script doit être lancé en root."
  exit 1
fi

############################################
# 0️⃣ Pré-requis de base
############################################
echo "[0/10] Installation des outils de base..."
apt update -y
apt install -y curl wget gnupg lsb-release ca-certificates apt-transport-https

############################################
# 1️⃣ Désactiver le swap
############################################
echo "[1/10] Désactivation du swap..."
swapoff -a
sed -i '/ swap / s/^/#/' /etc/fstab || true

############################################
# 2️⃣ Config kernel: modules + sysctl
#   -> inspiré du doc (overlay, br_netfilter, ip_forward=1)
############################################
echo "[2/10] Configuration des modules noyau et sysctl..."

cat >/etc/modules-load.d/k8s.conf <<EOF
overlay
br_netfilter
EOF

modprobe overlay
modprobe br_netfilter

cat >/etc/sysctl.d/99-kubernetes-cri.conf <<EOF
net.ipv4.ip_forward                 = 1
EOF

sysctl --system

############################################
# 3️⃣ Installation et configuration de containerd
############################################
echo "[3/10] Installation de containerd..."

apt install -y containerd

mkdir -p /etc/containerd
containerd config default | tee /etc/containerd/config.toml >/dev/null

# SystemdCgroup = true comme dans la doc
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

systemctl restart containerd
systemctl enable containerd

############################################
# 4️⃣ Installation de crictl (client CRI)
############################################
echo "[4/10] Installation de crictl..."

CRICTL_VERSION="v1.30.0"
cd /tmp
curl -LO https://github.com/kubernetes-sigs/cri-tools/releases/download/${CRICTL_VERSION}/crictl-${CRICTL_VERSION}-linux-amd64.tar.gz
tar zxvf crictl-${CRICTL_VERSION}-linux-amd64.tar.gz -C /usr/local/bin
rm crictl-${CRICTL_VERSION}-linux-amd64.tar.gz

# Configurer crictl pour parler à containerd
cat >/etc/crictl.yaml <<EOF
runtime-endpoint: unix:///run/containerd/containerd.sock
image-endpoint:  unix:///run/containerd/containerd.sock
timeout: 10
debug: false
pull-image-on-create: false
EOF

############################################
# 5️⃣ Installation kubeadm / kubelet / kubectl
############################################
echo "[5/10] Installation kubeadm / kubelet / kubectl..."

mkdir -p /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key \
  | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

cat >/etc/apt/sources.list.d/kubernetes.list <<EOF
deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /
EOF

apt update -y
apt install -y kubeadm kubelet kubectl
apt-mark hold kubeadm kubelet kubectl

############################################
# 6️⃣ kubeadm init (sans options, comme demandé)
############################################
echo "[6/10] Initialisation du cluster avec kubeadm init (sans options)..."

# kubeadm init peut être long
kubeadm init

############################################
# 7️⃣ Récupération de la commande kubeadm join
############################################
echo "[7/10] Récupération de la commande kubeadm join..."

JOIN_CMD="$(kubeadm token create --print-join-command)"

echo "===== kubeadm join à utiliser pour ajouter des noeuds ====="
echo "${JOIN_CMD}"
echo "${JOIN_CMD}" >/root/kubeadm_join.txt
echo "Commande sauvegardée dans /root/kubeadm_join.txt"

############################################
# 8️⃣ Configuration kubectl pour root
############################################
echo "[8/10] Configuration de kubectl pour l'utilisateur root..."

mkdir -p /root/.kube
cp -i /etc/kubernetes/admin.conf /root/.kube/config
chown root:root /root/.kube/config

export KUBECONFIG=/etc/kubernetes/admin.conf

############################################
# 9️⃣ Installation du CNI Calico
############################################
echo "[9/10] Installation du CNI Calico..."

cd /root
curl -LO https://raw.githubusercontent.com/projectcalico/calico/refs/heads/master/manifests/calico.yaml
kubectl apply -f calico.yaml

# Single node : enlever le taint pour que les workloads s'exécutent sur le control-plane
kubectl taint nodes --all node-role.kubernetes.io/control-plane- || true
kubectl taint nodes --all node-role.kubernetes.io/master- || true

echo "====================================="
echo " ✅ Installation terminée"
echo " - Cluster initialisé avec kubeadm init"
echo " - Calico installé"
echo " - Helm installé"
echo " - cert-manager installé"
echo ""
echo "📌 Commande kubeadm join pour ajouter des noeuds :"
echo "   ${JOIN_CMD}"
echo "   (également dans /root/kubeadm_join.txt)"
echo "====================================="
