# PrêtLab

L'API qui sait qui a emprunté quel matériel du labo, et **refuse de le prêter deux fois**.
Petite application Flask + PostgreSQL, livrée avec sa chaîne DevOps complète :
Git, script de contrôle, Docker multi-stage, Compose, CI GitHub Actions, version immuable sur
ghcr.io, mise en service en staging avec `deploy.sh` et retour arrière.

## Démarrer en UNE commande

Prérequis : Docker avec Compose, et `make`.

```bash
make up
```

`make up` crée `.env` depuis `.env.example` si besoin, construit l'image, démarre l'API et
PostgreSQL, et attend que tout soit sain. Vérifier :

```bash
curl http://localhost:8080/health
curl http://localhost:8080/version
```

Arrêter (les données restent dans le volume `pgdata`) : `make down`. Toutes les commandes : `make help`.

## Utiliser l'API

```bash
curl -X POST -H 'Content-Type: application/json' \
  -d '{"name":"Carte Arduino","tag":"ARD-001"}' http://localhost:8080/equipment
curl -X POST -H 'Content-Type: application/json' \
  -d '{"equipment_id":1,"borrower":"Amel","days":7}' http://localhost:8080/loans
curl 'http://localhost:8080/loans?active=true'
curl -X POST http://localhost:8080/loans/1/return
```

| Route | Rôle |
|---|---|
| `GET /health` | le processus répond (vivacité) et affiche la version |
| `GET /ready` | la base répond (503 sinon) |
| `GET /version` | version et commit de l'image en service |
| `GET` / `POST /equipment` | liste / ajout du matériel |
| `GET` / `POST /loans` | liste des prêts (`?active=true`) / nouveau prêt (409 si déjà prêté) |
| `POST /loans/<id>/return` | retour du matériel |

## Développer

```bash
python3 -m venv .venv && . .venv/bin/activate
pip install -r requirements-dev.txt
make hooks     # hooks Git : anti-secrets, lint, format des messages de commit
make test      # tests unitaires + tests du script de déploiement
make lint
make check     # scripts/check.sh
```

## Documentation du projet

- `GUIDE_COMMANDES.md` : le guide pas à pas, de zéro à la soutenance
- `FICHE_1_PAGE.md` : architecture, version mise en service, retour arrière
- `DEMO_SOUTENANCE.md` : script de 10 minutes et questions probables
- `TABLEAU_CONFORMITE.md` : chaque exigence du sujet, où elle est satisfaite, comment la prouver
- `URLS_PIPELINES.md` : les deux URLs de pipeline à fournir et comment les produire

> Les mots de passe de ce dépôt sont fictifs et réservés à un usage local.
> Aucun fichier `.env` n'est versionné, seulement `.env.example`.
