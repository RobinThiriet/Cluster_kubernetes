
# Teleport - Windows Desktop Access avec Active Directory

## Objectif

Cette documentation décrit la mise en place de **Teleport Windows Desktop Access** dans le lab Kubernetes/Active Directory.

L'objectif est de permettre l'accès RDP aux machines Windows du domaine Active Directory depuis l'interface Web Teleport.

---

## Architecture du lab

| Élément                          | Valeur                       |
| -------------------------------- | ---------------------------- |
| Cluster Kubernetes               | kubeadm local                |
| Namespace Teleport               | `teleport`                   |
| Proxy Teleport                   | `teleport.local`             |
| IP LoadBalancer Teleport         | `192.168.1.205`              |
| Domaine Active Directory         | `rt.local`                   |
| NetBIOS AD                       | `RT`                         |
| Contrôleur de domaine            | `DC01.rt.local`              |
| IP du contrôleur de domaine      | `192.168.1.50`               |
| Port LDAPS                       | `636`                        |
| Hôte Linux Teleport Agent        | `ubuntu`                     |
| IP hôte Linux                    | `192.168.1.30`               |
| Fichier agent SSH Linux          | `/etc/teleport.yaml`         |
| Fichier Windows Desktop Service  | `/etc/teleport-windows.yaml` |
| Data dir Windows Desktop Service | `/var/lib/teleport-windows`  |
| Service systemd SSH Linux        | `teleport.service`           |
| Service systemd Windows Desktop  | `teleport-windows.service`   |

---

## Principe important

Il ne faut pas mélanger l'agent SSH Linux et le Windows Desktop Service.

### Agent SSH Linux

L'agent SSH Linux officiel reste configuré dans :

```text
/etc/teleport.yaml
```

Ce fichier est géré par l'installation officielle de l'agent Teleport.

Il contient notamment :

```yaml
ssh_service:
  enabled: "yes"
```

Il ne faut pas y ajouter le bloc `windows_desktop_service`.

### Windows Desktop Service

Le Windows Desktop Service est configuré séparément dans :

```text
/etc/teleport-windows.yaml
```

Il utilise aussi un répertoire de données séparé :

```text
/var/lib/teleport-windows
```

Et un service systemd dédié :

```text
teleport-windows.service
```

Cette séparation évite de casser l'agent SSH Linux déjà fonctionnel.

---

## Pré-requis Active Directory

Sur le contrôleur de domaine `DC01.rt.local`, les éléments suivants doivent être en place :

* Active Directory Domain Services opérationnel.
* Active Directory Certificate Services installé.
* LDAPS actif sur le port `636`.
* Certificat LDAPS émis pour `DC01.rt.local`.
* Compte de service Teleport `svc-teleport`.
* GPO Teleport appliquée au domaine.
* RDP autorisé sur les machines Windows ciblées.

Commandes utiles côté PowerShell administrateur :

```powershell
Test-NetConnection 127.0.0.1 -Port 636
Test-NetConnection 192.168.1.50 -Port 636

Get-ADUser -Identity svc-teleport | Select SamAccountName,SID

Get-ADDomain | Select DNSRoot,NetBIOSName,DistinguishedName
```

Valeurs du lab :

```text
DNSRoot:           rt.local
NetBIOSName:       RT
DistinguishedName: DC=rt,DC=local
svc-teleport SID:  S-1-5-21-4124763732-3442043943-3729823684-1104
```

---

## Bootstrap Active Directory Teleport

Depuis le cluster Teleport :

```bash
kubectl -n teleport exec deploy/teleport-cluster-auth -- \
  tctl desktop bootstrap > configure-ad.ps1
```

Le fichier `configure-ad.ps1` doit ensuite être exécuté sur le contrôleur de domaine dans une console PowerShell administrateur.

Le bootstrap prépare notamment :

* le compte de service `svc-teleport`,
* les permissions LDAP nécessaires,
* la GPO de blocage de login interactif du compte de service,
* la GPO d'accès Teleport,
* l'import de la CA Teleport,
* les règles nécessaires pour RDP.

Dans ce lab, le script a créé les objets principaux mais a échoué en fin d'exécution sur un fichier temporaire `windows.pem`. La suite a donc été corrigée manuellement.

---

## Pré-requis Ubuntu

L'hôte Ubuntu `192.168.1.30` exécute deux services Teleport séparés :

```text
teleport.service
teleport-windows.service
```

Le premier reste l'agent SSH Linux.

Le second est dédié au Windows Desktop Service.

---

## DNS Active Directory sur Ubuntu

Pour que la découverte Windows fonctionne correctement, Ubuntu doit utiliser le contrôleur de domaine comme DNS.

Dans ce lab :

```text
DNS AD: 192.168.1.50
Domaine: rt.local
```

Commande avec l'interface `ens33` :

```bash
sudo resolvectl dns ens33 192.168.1.50
sudo resolvectl domain ens33 rt.local
```

Vérification :

```bash
resolvectl status
host DC01.rt.local
host rt.local
host _ldap._tcp.dc._msdcs.rt.local
```

Le DNS doit pointer vers :

```text
192.168.1.50
```

Important : `/etc/hosts` peut aider pour un test simple, mais il ne remplace pas le DNS Active Directory. La découverte automatique des desktops dépend des enregistrements DNS/SRV AD.

---

## Faire confiance à la CA Active Directory

La CA Active Directory doit être installée dans le trust store Ubuntu.

Exemple :

```bash
sudo cp rt-local-CA.crt /usr/local/share/ca-certificates/rt-local-CA.crt
sudo update-ca-certificates
```

Vérification LDAPS :

```bash
openssl s_client \
  -connect DC01.rt.local:636 \
  -servername DC01.rt.local \
  -CAfile /usr/local/share/ca-certificates/rt-local-CA.crt \
  </dev/null
```

Résultat attendu :

```text
Verify return code: 0 (ok)
```

---

## Tester le compte LDAP

Installer les outils LDAP :

```bash
sudo apt update
sudo apt install -y ldap-utils
```

Tester le compte de service :

```bash
ldapwhoami \
  -H ldaps://DC01.rt.local \
  -D "RT\\svc-teleport" \
  -W
```

Résultat attendu :

```text
u:RT\svc-teleport
```

Ne pas utiliser `ldaps://192.168.1.50` pour ce test, car le certificat LDAPS est émis pour `DC01.rt.local`.

---

## Token Teleport Windows Desktop

Le Windows Desktop Service ne doit pas utiliser le token de l'agent SSH Linux.

Créer un token dédié :

```bash
kubectl -n teleport exec deploy/teleport-cluster-auth -- \
  tctl tokens add --type=windowsdesktop --ttl=1h
```

Ce token est temporaire et ne doit pas être commit dans Git.

---

## Configuration `/etc/teleport-windows.yaml`

Exemple de configuration utilisée dans ce lab :

```yaml
version: v3

teleport:
  nodename: ubuntu-windows-desktop
  data_dir: /var/lib/teleport-windows
  proxy_server: teleport.local:443
  ca_pin: "sha256:6fbdb62a6895db952b0d75f4f313972ac65e714d4624c7acfd8b2be5c4548bd5"
  join_params:
    token_name: "TON_TOKEN_WINDOWSDESKTOP"
    method: token
  log:
    output: stderr
    severity: INFO
    format:
      output: text

auth_service:
  enabled: "no"

proxy_service:
  enabled: "no"

ssh_service:
  enabled: "no"

windows_desktop_service:
  enabled: "yes"
  ldap:
    addr: "DC01.rt.local:636"
    domain: "rt.local"
    username: 'RT\svc-teleport'
    sid: "S-1-5-21-4124763732-3442043943-3729823684-1104"
  discovery_configs:
    - base_dn: "DC=rt,DC=local"
      labels:
        env: lab
        domain: rt.local
```

Droits recommandés :

```bash
sudo chmod 600 /etc/teleport-windows.yaml
```

---

## Lancement manuel de test

Avant de créer ou d'activer systemd :

```bash
sudo teleport start \
  --config=/etc/teleport-windows.yaml \
  --debug
```

Signes positifs dans les logs :

```text
Teleport component has started
Connected to LDAP server
discovered Windows Desktops
```

---

## Service systemd dédié

Fichier :

```text
/etc/systemd/system/teleport-windows.service
```

Contenu :

```ini
[Unit]
Description=Teleport Windows Desktop Service
After=network-online.target teleport.service
Wants=network-online.target

[Service]
Type=simple
ExecStart=/usr/local/bin/teleport start --config=/etc/teleport-windows.yaml
Restart=on-failure
RestartSec=5
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
```

Activation :

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now teleport-windows
sudo systemctl status teleport-windows --no-pager -l
```

Logs :

```bash
sudo journalctl -u teleport-windows -n 100 --no-pager
sudo journalctl -u teleport-windows -f
```

---

## Vérification côté Teleport

Depuis le control-plane Kubernetes :

```bash
kubectl -n teleport exec deploy/teleport-cluster-auth -- \
  tctl get windows_desktop
```

Depuis l'interface Web Teleport :

```text
Resources -> Desktops
```

---

## RBAC Teleport

Créer un rôle Teleport autorisant l'accès aux desktops Windows.

Fichier :

```text
applications/teleport/rbac/windows-desktop-admins.yaml
```

Contenu :

```yaml
kind: role
version: v5
metadata:
  name: windows-desktop-admins
spec:
  allow:
    windows_desktop_labels:
      "*": "*"
    windows_desktop_logins:
      - Administrator
      - Administrateur
```

Appliquer le rôle :

```bash
kubectl -n teleport exec -i deploy/teleport-cluster-auth -- \
  tctl create -f - < applications/teleport/rbac/windows-desktop-admins.yaml
```

Ajouter le rôle à l'utilisateur Teleport `robin` :

```bash
kubectl -n teleport exec deploy/teleport-cluster-auth -- \
  tctl users update robin --set-roles=access,editor,windows-desktop-admins
```

Adapter ensuite les logins Windows selon les comptes réels du domaine.

---

## Dépannage

### Erreur : token does not allow role WindowsDesktop

Cause :

Le service utilise un token `node` au lieu d'un token `windowsdesktop`.

Correction :

```bash
kubectl -n teleport exec deploy/teleport-cluster-auth -- \
  tctl tokens add --type=windowsdesktop --ttl=1h
```

Puis mettre ce token dans :

```text
/etc/teleport-windows.yaml
```

Ne pas modifier le token de :

```text
/etc/teleport.yaml
```

---

### Erreur : Can't contact LDAP server avec l'IP

Commande problématique :

```bash
ldapwhoami -H ldaps://192.168.1.50 -D "RT\\svc-teleport" -W
```

Cause :

Le certificat LDAPS est émis pour `DC01.rt.local`, pas pour `192.168.1.50`.

Correction :

```bash
ldapwhoami -H ldaps://DC01.rt.local -D "RT\\svc-teleport" -W
```

---

### Erreur : could not resolve DC01.rt.local

Cause :

Ubuntu utilise le routeur comme DNS au lieu du contrôleur de domaine.

Correction :

```bash
sudo resolvectl dns ens33 192.168.1.50
sudo resolvectl domain ens33 rt.local
```

Puis vérifier :

```bash
host DC01.rt.local
host _ldap._tcp.dc._msdcs.rt.local
```

---

### Aucun desktop visible dans Teleport

Vérifier les logs :

```bash
sudo journalctl -u teleport-windows -n 100 --no-pager
```

Vérifier DNS, LDAPS et discovery :

```bash
host DC01.rt.local
host _ldap._tcp.dc._msdcs.rt.local

ldapwhoami \
  -H ldaps://DC01.rt.local \
  -D "RT\\svc-teleport" \
  -W

kubectl -n teleport exec deploy/teleport-cluster-auth -- \
  tctl get windows_desktop
```

Côté Windows :

```powershell
gpupdate /force
Test-NetConnection DC01.rt.local -Port 3389
```

---

## Sécurité

* Ne pas commit les tokens Teleport.
* Ne pas stocker le mot de passe `svc-teleport` dans Git.
* Utiliser un token `windowsdesktop` avec une durée courte.
* Garder `/etc/teleport-windows.yaml` en permission restrictive.
* En production, utiliser plusieurs contrôleurs de domaine ou un endpoint LDAPS hautement disponible.
* En production, séparer les rôles Teleport critiques sur plusieurs hôtes.

