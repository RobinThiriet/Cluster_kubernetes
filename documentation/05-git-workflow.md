# 05 - Workflow Git

## Principe

Le depot Git est la source de verite.

La branche main contient le socle stable.

Les tests applicatifs doivent etre faits dans une branche de travail.

## Configuration Git

    git config --global user.name "Robin Thiriet"
    git config --global user.email "EMAIL_GITHUB"

## Remote GitHub

Remote SSH recommande :

    git remote set-url origin git@github.com:RobinThiriet/Cluster_kubernetes.git

Verifier :

    git remote -v

## Cle SSH GitHub

Creer une cle :

    ssh-keygen -t ed25519 -C "EMAIL_GITHUB"

Afficher la cle publique :

    cat ~/.ssh/id_ed25519.pub

Ajouter la cle dans GitHub :

    GitHub
    Settings
    SSH and GPG keys
    New SSH key

Tester :

    ssh -T git@github.com

## Premier commit

    cd ~/kube-platform

    git branch -M main
    git status
    git add .
    git commit -m "bootstrap Kubernetes platform base"
    git push -u origin main

## Branche applications

    git checkout -b applications/poc
    git push -u origin applications/poc

Workflow :

    git checkout applications/poc
    git status
    git add .
    git commit -m "add application"
    git push

Ensuite faire une Pull Request :

    applications/poc -> main

## Ne jamais versionner

- kubeconfig
- tokens
- cles privees
- mots de passe
- fichiers .env
- Secrets Kubernetes en clair
