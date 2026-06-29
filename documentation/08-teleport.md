# 08 - Teleport

## Role

Teleport est une plateforme d'acces Zero Trust.

Dans ce cluster, Teleport est utilise pour centraliser et securiser les acces :

- acces Web a l'interface Teleport ;
- acces SSH vers des machines Linux ;
- future integration SSO avec Keycloak ;
- future preparation de Vault pour les secrets ;
- future automatisation du deploiement des agents avec Ansible.

Teleport remplace progressivement les acces directs du type :

    ssh user@server

par un acces controle :

    tsh ssh user@server

ou via l'interface Web Teleport.

## Objectif du POC

Le but de cette premiere etape est de valider :

- l'installation du cluster Teleport ;
- l'acces a l'interface Web ;
- la creation d'un utilisateur local temporaire ;
- l'enregistrement d'un agent Linux ;
- la connexion SSH vers une machine Linux via Teleport ;
- la comprehension des composants Teleport avant l'ajout de Keycloak et Vault.

## Architecture actuelle

    Client navigateur
       |
       v
    https://teleport.local
       |
       v
    Service LoadBalancer MetalLB
       |
       v
    Teleport Proxy
       |
       v
    Teleport Auth
       |
       v
    Agent Teleport Linux
       |
       v
    Machine Ubuntu

## Composants Teleport

### Auth Service

Le service Auth est le coeur du cluster Teleport.

Il gere :

- les utilisateurs ;
- les roles ;
- les tokens de jointure ;
- les certificats ;
- les ressources enregistrees ;
- les sessions ;
- l'audit.

Dans le cluster Kubernetes, il est deployee dans le namespace :

    teleport

Ressource principale :

    deployment/teleport-cluster-auth

### Proxy Service

Le Proxy est le point d'entree utilisateur.

Il expose :

- l'interface Web ;
- l'acces CLI avec tsh ;
- les connexions vers les ressources ;
- les flux d'acces SSH, Kubernetes, apps, databases, desktops selon les configurations.

Service expose :

    service/teleport-cluster

Adresse locale utilisee :

    https://teleport.local

IP MetalLB utilisee :

    192.168.1.205

### Agent Teleport

Un agent Teleport est installe sur ou pres de la ressource a proteger.

Pour une machine Linux, l'agent active :

    ssh_service

Pour Windows, on utilisera plus tard :

    windows_desktop_service

Pour une application Web :

    app_service

Pour une base de donnees :

    db_service

Pour Kubernetes :

    kubernetes_service

## Dossier Git

Teleport est range dans :

    applications/teleport/

Structure :

    applications/teleport/
    ├── charts/
    ├── values/
    ├── rendered/
    └── config/

## Installation Helm

### Creation du dossier

    cd ~/kube-platform
    mkdir -p applications/teleport/{charts,values,rendered,config}
    cd applications/teleport

### Ajout du repository Helm

    helm repo add teleport https://charts.releases.teleport.dev --force-update
    helm repo update teleport

### Verification des versions

    helm search repo teleport/teleport-cluster --versions | head -n 10

### Version utilisee

    export TELEPORT_VERSION="18.9.1"

### Telechargement du chart

    helm pull teleport/teleport-cluster \
      --version "$TELEPORT_VERSION" \
      --untar \
      --untardir charts

### Copie des values

    cp charts/teleport-cluster/values.yaml values/teleport-default.yaml
    cp charts/teleport-cluster/values.yaml values/teleport.yaml

Le fichier de reference est :

    values/teleport-default.yaml

Le fichier modifiable est :

    values/teleport.yaml

## Configuration Teleport retenue

Le fichier utilise est :

    applications/teleport/values/teleport.yaml

Configuration de base :

    clusterName: teleport.local

    proxyListenerMode: multiplex

    acme: false

    enterprise: false

    proxy:
      service:
        type: LoadBalancer

    auth:
      storage:
        type: kubernetes

Notes :

- `clusterName` correspond au nom local du cluster Teleport.
- `acme: false` car le lab n'a pas de DNS public ni certificat Let's Encrypt.
- le Proxy est expose via un Service LoadBalancer fourni par MetalLB.
- le stockage Auth utilise Kubernetes pour ce POC.

## Generation du manifeste

    helm template teleport-cluster charts/teleport-cluster \
      --namespace teleport \
      --values values/teleport.yaml \
      > rendered/teleport.yaml

## Creation du namespace

    kubectl create namespace teleport --dry-run=client -o yaml | kubectl apply -f -

Option de securite appliquee :

    kubectl label namespace teleport pod-security.kubernetes.io/enforce=baseline --overwrite

## Dry-run

    kubectl apply --dry-run=server -n teleport -f rendered/teleport.yaml

## Application

    kubectl apply -n teleport -f rendered/teleport.yaml

## Verification du cluster Teleport

    kubectl -n teleport get pods -o wide
    kubectl -n teleport get svc
    kubectl -n teleport get pvc

Etat attendu :

    teleport-cluster-auth    Running
    teleport-cluster-proxy   Running
    teleport-cluster         LoadBalancer
    teleport-cluster         PVC Bound

Service principal :

    teleport-cluster   LoadBalancer   192.168.1.205   443/TCP

## Resolution DNS locale

Sur le poste client ou la machine de test, ajouter :

    192.168.1.205 teleport.local

Puis tester :

    curl -k https://teleport.local/web

Resultat attendu :

    page HTML Teleport

## Creation d'un utilisateur local temporaire

Pour le POC, un utilisateur local a ete cree :

    kubectl -n teleport exec deploy/teleport-cluster-auth -- \
      tctl users add robin --roles=editor,access --logins=root,ubuntu,control-plane

Cette commande genere une URL d'invitation valable 1h.

Exemple :

    https://teleport.local:443/web/invite/...

Important :

- l'utilisateur local est acceptable pour un POC ;
- en entreprise, il faudra remplacer cela par du SSO via Keycloak ;
- le role `editor` est trop large pour une utilisation production.

## Enrolement d'un agent Linux

### Creation du token

Depuis le control-plane :

    kubectl -n teleport exec deploy/teleport-cluster-auth -- \
      tctl tokens add --type=node --ttl=1h

Teleport retourne :

- un token temporaire ;
- un CA pin ;
- une commande de jointure.

Le token est sensible et ne doit pas etre commite dans Git.

### Probleme rencontre avec teleport.local:443

L'agent Linux a d'abord tente de joindre :

    teleport.local:443

Erreur observee :

    tls: failed to verify certificate: x509: certificate signed by unknown authority

Cause :

- le certificat local de Teleport n'est pas signe par une CA reconnue ;
- le navigateur peut l'accepter manuellement ;
- l'agent Teleport verifie strictement le TLS.

### Contournement utilise pour le POC

Le service Auth a ete expose temporairement en NodePort :

    kubectl -n teleport patch svc teleport-cluster-auth \
      -p '{"spec":{"type":"NodePort"}}'

Verification :

    kubectl -n teleport get svc teleport-cluster-auth

Resultat obtenu :

    teleport-cluster-auth   NodePort   3025:31005/TCP,3026:32505/TCP

L'agent Linux a ensuite ete joint via :

    sudo teleport start \
      --debug \
      --roles=node \
      --token=TOKEN \
      --ca-pin=CA_PIN \
      --auth-server=192.168.1.100:31005 \
      --advertise-ip=192.168.1.30

Notes :

- `192.168.1.100` est l'IP du control-plane ;
- `31005` est le NodePort temporaire du port Auth 3025 ;
- `--advertise-ip=192.168.1.30` force l'adresse annoncee par l'agent ;
- `192.168.1.30` est l'IP de la machine Ubuntu cible.

## Nettoyage du service Auth

Une fois l'agent enregistre, le service Auth a ete remis en ClusterIP :

    kubectl -n teleport patch svc teleport-cluster-auth \
      -p '{"spec":{"type":"ClusterIP"}}'

Verification :

    kubectl -n teleport get svc teleport-cluster-auth

Resultat attendu :

    teleport-cluster-auth   ClusterIP   3025/TCP,3026/TCP

## Verification des nodes Teleport

Lister les nodes :

    kubectl -n teleport exec deploy/teleport-cluster-auth -- \
      tctl nodes ls

Lister en JSON :

    kubectl -n teleport exec deploy/teleport-cluster-auth -- \
      tctl nodes ls --format=json

Un ancien enregistrement incorrect avait ete cree avec une adresse Pod :

    10.244.0.42:3022

Un nouvel enregistrement correct a ete cree avec :

    192.168.1.30:3022

L'ancien node a ete supprime :

    kubectl -n teleport exec deploy/teleport-cluster-auth -- \
      tctl rm node/UUID_DU_MAUVAIS_NODE

## Probleme rencontre : mauvaise adresse annoncee

Symptome dans l'interface Web :

    Teleport proxy failed to connect to node agent "ubuntu"
    dial tcp 10.244.0.42:3022: connect: connection refused

Cause :

- un ancien enregistrement du node existait avec une mauvaise adresse ;
- Teleport affichait deux ressources avec le meme hostname `ubuntu`.

Correction :

- relancer l'agent avec `--advertise-ip=192.168.1.30` ;
- supprimer l'ancien node avec `tctl rm node/...`.

## Verification reseau agent Linux

Sur la machine Ubuntu :

    ip a

Adresse observee :

    192.168.1.30/24

Verification du port Teleport SSH :

    ss -lntp | grep 3022

Resultat attendu :

    LISTEN *:3022

Verification du process :

    sudo lsof -i :3022

Depuis le control-plane :

    nc -vz 192.168.1.30 3022

Resultat attendu :

    Connection to 192.168.1.30 3022 port succeeded

## Pourquoi teleport start bloque le terminal

La commande :

    sudo teleport start ...

demarre le service Teleport au premier plan.

C'est normal que le terminal reste bloque.

Ce comportement est equivalent a lancer un serveur en foreground.

Pour une installation persistante, il faudra utiliser systemd.

## Prochaine etape : systemd

L'agent Linux devra etre transforme en service systemd.

Fichier cible :

    /etc/systemd/system/teleport.service

Exemple :

    [Unit]
    Description=Teleport SSH Agent
    After=network-online.target
    Wants=network-online.target

    [Service]
    Type=simple
    ExecStart=/usr/local/bin/teleport start --config=/etc/teleport.yaml
    Restart=on-failure
    RestartSec=5
    LimitNOFILE=65536

    [Install]
    WantedBy=multi-user.target

Commandes :

    sudo systemctl daemon-reload
    sudo systemctl enable teleport
    sudo systemctl start teleport
    sudo systemctl status teleport

Logs :

    journalctl -u teleport -f

## Strategie cible entreprise

L'installation manuelle est uniquement pour le POC.

En entreprise, les agents ne doivent pas etre installes a la main serveur par serveur.

La strategie cible est :

    Ansible
       |
       v
    installation du binaire Teleport
       |
       v
    generation /etc/teleport.yaml depuis template
       |
       v
    creation du service systemd
       |
       v
    demarrage et verification de l'agent

## Arborescence Ansible cible

A terme, le depot devra contenir :

    ansible/
    ├── inventory/
    │   └── lab.ini
    ├── group_vars/
    │   └── all.yml
    ├── playbooks/
    │   └── install-teleport-agent-linux.yml
    └── roles/
        └── teleport-agent-linux/
            ├── defaults/
            │   └── main.yml
            ├── tasks/
            │   └── main.yml
            └── templates/
                ├── teleport.yaml.j2
                └── teleport.service.j2

## Exemple de template Linux cible

    version: v3

    teleport:
      nodename: "{{ inventory_hostname }}"
      data_dir: /var/lib/teleport
      proxy_server: teleport.local:443
      ca_pin: "{{ teleport_ca_pin }}"
      join_params:
        token_name: "{{ teleport_join_token }}"
        method: token

    auth_service:
      enabled: false

    proxy_service:
      enabled: false

    ssh_service:
      enabled: true
      listen_addr: 0.0.0.0:3022
      public_addr: "{{ ansible_host }}:3022"
      labels:
        env: "{{ teleport_env }}"
        os: linux
        role: "{{ teleport_role }}"

## Points importants pour l'entreprise

### Ne pas utiliser durablement les utilisateurs locaux

L'utilisateur local `robin` est utile pour le POC.

En entreprise, il faudra utiliser :

- Keycloak ;
- SSO ;
- MFA ;
- groupes ;
- mapping groupes vers roles Teleport.

### Ne pas donner editor a tout le monde

Le role `editor` est trop large.

Il faudra creer des roles dedies :

- platform-admin ;
- linux-admin-lab ;
- linux-admin-prod ;
- readonly ;
- application-access.

### Utiliser les labels

Les labels permettent de piloter les acces :

    env: lab
    os: linux
    role: test
    team: platform

Les roles Teleport doivent donner acces en fonction des labels, pas en fonction de noms de machines isoles.

### Versionner les roles

Les roles Teleport devront etre stockes dans Git sous forme YAML.

Exemple futur :

    applications/teleport/config/roles/

Puis appliques avec :

    tctl create -f role.yaml

### Ne pas versionner les secrets

Ne jamais mettre dans Git :

- token de join ;
- ca-pin si considere sensible dans le contexte ;
- mots de passe ;
- cles privees ;
- kubeconfig ;
- fichiers .env ;
- secrets Kubernetes.

## Ce qui reste a faire

- creer un fichier `/etc/teleport.yaml` propre pour l'agent Linux ;
- creer le service systemd ;
- documenter le deploiement agent Linux ;
- preparer un role Ansible ;
- tester un agent Windows Server ;
- installer Keycloak ;
- connecter Keycloak a Teleport ;
- preparer Vault pour les secrets.
