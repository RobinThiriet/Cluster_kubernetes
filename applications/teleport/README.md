# Teleport

Ce dossier contient les fichiers de deploiement de Teleport.

## Role

Teleport fournit une interface centralisee pour acceder aux ressources du lab :

- Web UI ;
- acces SSH ;
- futur SSO Keycloak ;
- futurs acces Kubernetes, applications, bases de donnees ou desktops.

## Structure

    applications/teleport/
    ├── charts/
    ├── values/
    ├── rendered/
    └── config/

## Version

    Teleport chart : 18.9.1

## Exposition

Teleport Proxy est expose via MetalLB :

    https://teleport.local

IP utilisee :

    192.168.1.205

## Verification

    kubectl -n teleport get pods -o wide
    kubectl -n teleport get svc
    kubectl -n teleport get pvc

## Utilisateur local POC

Un utilisateur local temporaire a ete cree pour les tests :

    robin

En entreprise, cet utilisateur devra etre remplace par une authentification SSO Keycloak.

## Agent Linux POC

Un agent Linux a ete teste avec :

    ssh_service

Machine cible :

    ubuntu
    192.168.1.30

Port Teleport SSH :

    3022

## Documentation detaillee

Voir :

    documentation/08-teleport.md
