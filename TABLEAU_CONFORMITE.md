# Tableau de conformité — sujet → où c'est satisfait → comment le prouver

Statut : ✅ vérifié lors de la création du dépôt · 🖥️ à exécuter sur ta machine (preuve à produire toi-même).

## Points essentiels (16 pts)

| # | Exigence du sujet | Où c'est satisfait | Comment le prouver | Statut |
|---|---|---|---|---|
| 1 (2) | Commits clairs, branches + PR, `.gitignore`, aucun secret | Historique préfixé (`feat:`, `ci:`…), hooks `commit-msg` et `pre-commit`, `.gitignore` (`.env`, `.env.*` sauf `.env.example`), modèle `.github/pull_request_template.md` | `git log --oneline --graph --all` ; `git ls-files \| grep '\.env'` (seul `.env.example`) ; `git check-ignore -v .env` ; PR visibles sur GitHub avec description et commentaire | ✅ historique, hooks / 🖥️ PR |
| 2 (2) | Script Bash : 0 succès, ≠ 0 échec | `scripts/check.sh` (`set -euo pipefail`, sortie colorée, codes 0/1/2), réutilisé par le hook et la CI | `./scripts/check.sh; echo $?` en succès (0), puis avec un fichier retiré (1), puis `--zzz` (2) | ✅ |
| 3 (3) | Dockerfile, `.dockerignore`, tag explicite, non root, HEALTHCHECK | `Dockerfile` multi-stage, `python:3.12.8-slim-bookworm`, `USER app`, `HEALTHCHECK`, labels OCI ; `.dockerignore` | `docker exec <c> whoami` → `app` ; `docker inspect --format '{{.State.Health.Status}}'` → `healthy` ; `docker inspect --format '{{json .Config.Labels}}'` ; `docker history` | ✅ règles contrôlées par `check.sh` / 🖥️ build et exécution |
| 4 (3) | Compose : app + base, nom de service, port base non publié, volume, démarrage sur santé, config `.env` | `compose.yaml` (`DB_HOST: db`, aucun `ports` pour `db`, volume `pgdata`, `condition: service_healthy`, `${POSTGRES_*:?}`), `Makefile` (`make up`) | `docker compose config -q` ; `docker compose port db 5432` (rien) ; prêt toujours présent après `down` puis `make up` | ✅ `config` / 🖥️ reste |
| 5 (3) | CI sur PR : tests puis build (`needs`), rapport en artefact | `.github/workflows/ci.yml` : `lint`, `test` (matrice, JUnit en artefact, `if: always()`), `docker-build` avec `needs: [lint, test]` ; cache pip ; `permissions: contents: read` | PR verte : jobs et artefacts visibles ; PR rouge : `docker-build` ignoré | ✅ actionlint propre / 🖥️ exécution |
| 6 (2) | Tag `vX.Y.Z`, image construite une fois et poussée sur ghcr.io, jamais reconstruite, staging avec `IMAGE_TAG`, `wait-healthy.sh`, version exposée | `release.yml` (build sur tag, `VERSION`/`REVISION` gravés), `compose.staging.yaml` (`image:` sans `build:`), `scripts/deploy.sh`, `scripts/wait-healthy.sh`, route `/version` | `git show v1.0.0` ; package ghcr.io `:v1.0.0` ; `deploy.sh v1.0.0` puis `curl /version` → `v1.0.0` | ✅ logique de `deploy.sh` (docker simulé) / 🖥️ reste |
| 7 (1) | v1.0.0 → v1.1.0 → retour à v1.0.0, avec preuve | `scripts/deploy.sh --previous` (ou `deploy.sh v1.0.0`), `.deploy-state` | `/version` → `v1.0.0` ; `/loans/overdue` → 404 ; `time` du retour ; sorties dans `preuves/rollback-v1.0.0.txt` | ✅ logique / 🖥️ démonstration réelle |

## Soutenance (4 pts)

| Exigence | Où | Preuve | Statut |
|---|---|---|---|
| Démo 10 min : PR verte, PR rouge + première erreur utile, mise en service, retour arrière | `DEMO_SOUTENANCE.md` | Répétition chronométrée | 🖥️ |

## Bonus (+4 max, note plafonnée à 20)

| Bonus | Où | Preuve | Statut |
|---|---|---|---|
| Déploiement auto sur tag (+2) | Job `deploy-staging` de `release.yml` (appelle `deploy.sh`) | Exécution Release avec `ci`, `publish`, `deploy-staging` verts | 🖥️ |
| Protection de `main` (+1) | Réglage GitHub (GUIDE étape 13.1) | Capture : fusion bloquée sur la PR rouge | 🖥️ |
| Matrice de versions (+1) | `ci.yml` (`matrix.python`, `fail-fast: false`) | Jobs `test (3.11)` et `test (3.12)` ; résultats expliqués | ✅ actionlint / 🖥️ |
| Profil debug Compose (+1) | `adminer` avec `profiles: ["debug"]`, `make debug` | `make up` (pas d'adminer) puis `make debug` | ✅ config / 🖥️ |
| Image allégée (+1) | GUIDE étape 13.5 | Deux tailles + `docker history` avant/après | 🖥️ |
| Compte rendu d'incident (+1) | GUIDE étape 13.6 → `docs/incident-01.md` | Fichier rédigé avec **tes** observations | 🖥️ |

## À rendre

| Élément | Statut |
|---|---|
| Dépôt Git avec README « une commande » (`make up`) | ✅ `README.md` |
| URL d'un pipeline vert + d'un pipeline rouge | 🖥️ voir `URLS_PIPELINES.md` |
| Fiche d'une page (architecture, version, rollback) | ✅ gabarit `FICHE_1_PAGE.md` à compléter (durée du retour arrière, digest, URL) |
