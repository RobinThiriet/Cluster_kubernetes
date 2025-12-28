#!/usr/bin/env bash
set -euo pipefail

############################################
# Config (à adapter)
############################################
K8S_MAJOR_MINOR="v1.30"
CRICTL_VERSION="v1.30.0"

# Ingress NGINX
INGRESS_NGINX_VERSION="v1.11.1"

# cert-manager
CERT_MANAGER_VERSION="v1.16.3"

# Email Let's Encrypt (obligatoire)
LETSENCRYPT_EMAIL="robin.thiriet@exotrail.com"

# ClusterIssuer name
CLUSTER_ISSUER_NAME="letsencrypt-prod"

############################################
# Helpers
############################################
log() { echo -e "\n\033[1;34m[INFO]\033[0m $*"; }
warn() { echo -e "\n\033[1;33m[WARN]\033[0m $*"; }
die() { echo -e "\n\033[1;31m[ERR]\033[0m $*"; exit 1; }

need_root() {
  if [ "$(id -u)" -ne 0 ]; then
    die "Ce script doit être lancé en root."
  fi
}

wait_for_pods_ready() {
  local ns="$1"
  local timeout="${2:-300s}"
  log "Attente des pods Ready dans namespace=$ns (timeout=$timeout)..."
  kubectl wait --namespace "$ns" --for=condition=Ready pods --all --timeout="$timeout" || {
    warn "Pods pas tous Ready dans $ns. Voici l'état:"
    kubectl get pods -n "$ns" -o wide || true
    return 1
  }
}

############################################
# 0) Pré-requis
############################################
need_root

log "Installation des outils de base..."
apt update -y
apt install -y curl wget gnupg lsb-release ca-certificates apt-transport-https jq

############################################
# 1) Désactiver swap
############################################
log "Désactivation du swap..."
swapoff -a
sed -i '/ swap / s/^/#/' /etc/fstab || true

############################################
# 2) Kernel modules + sysctl (bridge + ip_forward)
############################################
log "Configuration modules noyau + sysctl..."
cat >/etc/modules-load.d/k8s.conf <<EOF
overlay
br_netfilter
EOF

modprobe overlay || true
modprobe br_netfilter || true

cat >/etc/sysctl.d/99-kubernetes-cri.conf <<EOF
net.ipv4.ip_forward                 = 1
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF

sysctl --system

############################################
# 3) containerd
############################################
log "Installation et configuration de containerd..."
apt install -y containerd
mkdir -p /etc/containerd
containerd config default | tee /etc/containerd/config.toml >/dev/null

# SystemdCgroup=true recommandé pour kubelet + containerd
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

systemctl restart containerd
systemctl enable containerd

############################################
# 4) crictl
############################################
log "Installation de crictl..."
cd /tmp
curl -fsSLO "https://github.com/kubernetes-sigs/cri-tools/releases/download/${CRICTL_VERSION}/crictl-${CRICTL_VERSION}-linux-amd64.tar.gz"
tar zxvf "crictl-${CRICTL_VERSION}-linux-amd64.tar.gz" -C /usr/local/bin
rm -f "crictl-${CRICTL_VERSION}-linux-amd64.tar.gz"

cat >/etc/crictl.yaml <<EOF
runtime-endpoint: unix:///run/containerd/containerd.sock
image-endpoint:  unix:///run/containerd/containerd.sock
timeout: 10
debug: false
pull-image-on-create: false
EOF

############################################
# 5) kubeadm/kubelet/kubectl
############################################
log "Installation kubeadm / kubelet / kubectl..."
mkdir -p /etc/apt/keyrings
curl -fsSL "https://pkgs.k8s.io/core:/stable:/${K8S_MAJOR_MINOR}/deb/Release.key" \
  | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

cat >/etc/apt/sources.list.d/kubernetes.list <<EOF
deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/${K8S_MAJOR_MINOR}/deb/ /
EOF

apt update -y
apt install -y kubeadm kubelet kubectl
apt-mark hold kubeadm kubelet kubectl

systemctl enable kubelet

############################################
# 6) kubeadm init (si pas déjà fait)
############################################
if [ -f /etc/kubernetes/admin.conf ]; then
  warn "Cluster semble déjà initialisé (/etc/kubernetes/admin.conf existe). On saute kubeadm init."
else
  log "Initialisation du cluster kubeadm..."
  kubeadm init
fi

############################################
# 7) kubeconfig root + join cmd
############################################
log "Configuration kubectl pour root..."
mkdir -p /root/.kube
cp -f /etc/kubernetes/admin.conf /root/.kube/config
chown root:root /root/.kube/config
export KUBECONFIG=/etc/kubernetes/admin.conf

log "Commande kubeadm join..."
JOIN_CMD="$(kubeadm token create --print-join-command || true)"
if [ -n "${JOIN_CMD:-}" ]; then
  echo "${JOIN_CMD}" | tee /root/kubeadm_join.txt >/dev/null
  log "Join sauvegardé dans /root/kubeadm_join.txt"
else
  warn "Impossible de générer la commande join (cluster peut-être déjà initialisé)."
fi

############################################
# 8) CNI Calico
############################################
log "Installation Calico..."
cd /root
curl -fsSLO https://raw.githubusercontent.com/projectcalico/calico/refs/heads/master/manifests/calico.yaml
kubectl apply -f calico.yaml

# Attendre Calico (souvent utile)
sleep 5
kubectl get pods -n kube-system -o wide || true

############################################
# 9) Single node: enlever taints control-plane
############################################
log "Single-node: suppression taints control-plane/master..."
kubectl taint nodes --all node-role.kubernetes.io/control-plane- || true
kubectl taint nodes --all node-role.kubernetes.io/master- || true

############################################
# 10) Installer Helm
############################################
if command -v helm >/dev/null 2>&1; then
  log "Helm déjà installé."
else
  log "Installation Helm..."
  curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
fi

############################################
# 11) Installer ingress-nginx (LB DO)
############################################
log "Installation ingress-nginx (créera un Service type LoadBalancer)..."
kubectl apply -f "https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-${INGRESS_NGINX_VERSION}/deploy/static/provider/cloud/deploy.yaml"

# Attendre que le controller soit prêt
wait_for_pods_ready "ingress-nginx" "300s" || true

log "Service ingress-nginx-controller:"
kubectl get svc -n ingress-nginx ingress-nginx-controller -o wide || true

############################################
# 12) Installer cert-manager
############################################
log "Installation cert-manager..."
kubectl apply -f "https://github.com/cert-manager/cert-manager/releases/download/${CERT_MANAGER_VERSION}/cert-manager.yaml"

wait_for_pods_ready "cert-manager" "300s" || true

############################################
# 13) Créer ClusterIssuer Let's Encrypt (HTTP-01 via nginx)
############################################
log "Création ClusterIssuer Let's Encrypt (${CLUSTER_ISSUER_NAME})..."
cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: ${CLUSTER_ISSUER_NAME}
spec:
  acme:
    email: ${LETSENCRYPT_EMAIL}
    server: https://acme-v02.api.letsencrypt.org/directory
    privateKeySecretRef:
      name: ${CLUSTER_ISSUER_NAME}-account-key
    solvers:
      - http01:
          ingress:
            class: nginx
EOF

log "ClusterIssuer actuel:"
kubectl get clusterissuer "${CLUSTER_ISSUER_NAME}" -o wide || true

############################################
# Done
############################################
log "✅ Terminé."
echo "------------------------------------------------------------"
echo "Prochaines étapes importantes :"
echo "1) Récupérer l'IP du LB Ingress:"
echo "   kubectl get svc -n ingress-nginx ingress-nginx-controller -o wide"
echo "2) Configurer le DNS (A record) vers l'EXTERNAL-IP du LB"
echo "3) Créer un Ingress TLS avec:"
echo "   annotations cert-manager.io/cluster-issuer: ${CLUSTER_ISSUER_NAME}"
echo "   spec.tls.secretName: <secret>"
echo "------------------------------------------------------------"
