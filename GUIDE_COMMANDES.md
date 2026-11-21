# GUIDE_COMMANDES — Projet de fin de module DevOps : PrêtLab

Ce guide te fait refaire **seul, de zéro, sur ta machine (Linux ou WSL2 Ubuntu)** toute la chaîne du projet.
Chaque étape donne : l'objectif, les commandes dans l'ordre, ce qu'il faut observer, *pourquoi on le fait*, et les erreurs courantes.

## Comment lire ce guide (honnêteté sur ce qui a été vérifié)

| Marque | Signification |
|---|---|
| ✅ **Vérifié** | Exécuté pendant la création du dépôt (voir l'annexe C pour le détail exact). |
| 🖥️ **À exécuter sur votre machine** | Le démon Docker, GitHub Actions, ghcr.io et le staging n'étaient **pas** disponibles à la création. Les fichiers sont fournis ; **c'est toi** qui produis les vraies sorties, URLs et captures. |

Les sections « À observer » décrivent le résultat attendu **en mots**. Aucune sortie, URL ni résultat de registre n'a été inventé : tes propres sorties sont tes preuves.

---

## Étape 0 — Le projet, la checklist, les hypothèses

### 0.1 Le projet : PrêtLab

API de prêt de matériel de laboratoire. Flask + PostgreSQL. Règle métier : **un objet déjà prêté ne peut pas être reprêté**, garantie *par la base* (index unique partiel). Le code est petit ; la chaîne est ce qui est noté.

```
equipment(id, name, tag UNIQUE)
loans(id, equipment_id → equipment, borrower, borrowed_at, due_at, returned_at NULL)
                                   un seul prêt « en cours » (returned_at NULL) par objet
```

**L'histoire de version** qui rend le retour arrière visible : la **v1.1.0** ajoute `GET /loans/overdue` (prêts en retard). Revenir à la **v1.0.0** fait donc répondre 404 à cette route : preuve simple et honnête.

### 0.2 Checklist extraite du sujet

| # | Exigence du sujet | Pts | Où dans ce guide |
|---|---|---|---|
| 1 | Git propre : commits clairs, branches + merge requests, `.gitignore`, aucun secret | 2 | Étapes 2, 7, 8 |
| 2 | Script Bash de contrôle : 0 en succès, non nul en échec | 2 | Étape 3 |
| 3 | Dockerfile, `.dockerignore`, tag explicite, non root, HEALTHCHECK | 3 | Étape 5 |
| 4 | Compose : app + base, nom de service, port base non publié, volume, démarrage sur santé | 3 | Étape 6 |
| 5 | CI sur merge request : tests puis build (`needs`), rapport en artefact | 3 | Étape 8 |
| 6 | Tag `vX.Y.Z`, image publiée jamais reconstruite, staging + contrôle de santé | 2 | Étapes 9, 10 |
| 7 | Retour arrière démontré | 1 | Étape 12 |
| — | Soutenance 10 min | 4 | `DEMO_SOUTENANCE.md` |
| B1 | Déploiement automatique sur tag | +2 | Étape 13.2 |
| B2 | Protection de `main` | +1 | Étape 13.1 |
| B3 | Matrice de versions | +1 | Étape 13.3 |
| B4 | Profil debug Compose (adminer) | +1 | Étape 13.4 |
| B5 | Image allégée avant/après | +1 | Étape 13.5 |
| B6 | Compte rendu d'incident | +1 | Étape 13.6 |

16 + 4 = 20 : les bonus (+4 max, note **plafonnée à 20**) ne comptent que si les 7 essentiels sont là. Ils servent de filet de sécurité.

### 0.3 Hypothèses et écarts (le sujet l'emporte)

- Plateforme = **GitHub** ; « merge request » du sujet = **pull request**. Si GitLab est exigé : annexe A.
- Travail dans `~/devops-l3/projet/pretlab`, **dans WSL, jamais dans `/mnt/c`**.
- Projet individuel : tu ouvres et relis tes propres PR (un camarade peut commenter).

| Sujet / ateliers | Choix ici | Pourquoi |
|---|---|---|
| Ateliers : Dockerfile simple | **Multi-stage**, tags épinglés (`python:3.12.8-slim-bookworm`), labels OCI | Image plus petite, traçable |
| Atelier 4 : mot de passe dans `compose.yaml` | Configuration par `.env` (non versionné) + `.env.example` | Rappel de sécurité de l'atelier 4 |
| Atelier 5 : `compose.staging.yaml` avec propriétaire en dur | `IMAGE_REPO` + `IMAGE_TAG` | ghcr.io exige des minuscules ; rien à éditer |
| Atelier 5 : retour arrière à la main | **`scripts/deploy.sh <tag>`** pour déployer *et* revenir en arrière | Une seule commande, testée |
| Atelier 2 : `set -u` | `set -euo pipefail`, sortie colorée | Consigne du projet |
| `/health` seul | `/health` (vivacité) + `/ready` (base) + `/version` | Vérifier **quelle** version tourne et si la base répond |
| Postgres « 17-alpine » | `postgres:17-alpine` (tag de l'atelier 4) | Convention du cours |

---

## Étape 1 — Préparer le poste et récupérer le dépôt 🖥️

**Objectif** : un poste reproductible, le dépôt en place.

```bash
uname -a && head -3 /etc/os-release && whoami && pwd
git --version && docker version && docker compose version && python3 --version && make --version | head -1
sudo apt update && sudo apt install -y git curl make tree python3-venv   # si un outil manque
mkdir -p ~/devops-l3/projet && cd ~/devops-l3/projet
unzip pretlab.zip                          # ou : cp -r /chemin/vers/pretlab .
cd pretlab
git config user.name "Prénom Nom"
git config user.email "ton.adresse@exemple.tn"
git log --oneline
git branch -a                              # main, feature/overdue-loans, demo/pr-rouge
tree -a -I '.git|.venv'
```

**À observer** : chaque commande répond ; `git log` montre des commits préfixés (`chore:`, `feat:`, `test:`, `build:`, `ci:`, `docs:`).

**Pourquoi** : l'identité Git est écrite dans chaque commit, définitivement.

| Erreur | Cause → correction |
|---|---|
| `Cannot connect to the Docker daemon` | Docker Desktop arrêté ou intégration WSL2 désactivée → la démarrer / l'activer |
| `permission denied ... docker.sock` | `sudo usermod -aG docker $USER`, rouvrir la session. Jamais `sudo docker` |
| `make: command not found` | `sudo apt install make` |
| Droits bizarres, lenteur | Projet dans `/mnt/c` → le déplacer dans `~/devops-l3` |

---

## Étape 2 — Git propre (2 pts) ✅

**Objectif** : un historique lisible, des garde-fous automatiques, aucun secret.

```bash
cd ~/devops-l3/projet/pretlab
python3 -m venv .venv && . .venv/bin/activate
pip install -r requirements-dev.txt
make hooks                                  # active pre-commit et commit-msg
git log --oneline --graph --decorate --all
git ls-files | grep -E '(^|/)\.env' || echo "aucun .env versionné"
git check-ignore -v .env .env.staging .env.deploy    # les trois sont ignorés
```

**Tester les hooks** (✅ vérifié à la création) :

```bash
echo "x" >> README.md && git add README.md
git commit -m "modifs"                      # REFUSÉ : message hors convention
git commit -m "docs: tester le hook de message"      # accepté
git reset --hard HEAD~1                     # annule ce commit de test (il n'est pas poussé)
```

**Règles tenues tout au long du projet**

- Une intention par commit ; message `type: message` (types `feat fix docs test chore ci build refactor perf`).
- Jamais `git add .` sans avoir lu `git status`. Jamais de push direct sur `main` : tout passe par une pull request.
- Seul `.env.example` est versionné (valeurs fictives).
- Le hook *pre-commit* bloque un fichier `.env` suivi, une clé privée, un jeton GitHub ou une clé AWS, puis lance `ruff`.

**Pourquoi** : un secret poussé est compromis même supprimé ensuite (l'historique est copié). Mieux vaut l'empêcher avant le commit que le réparer après.

| Erreur | Correction |
|---|---|
| Hook non exécuté | `make hooks` (réglage local à chaque clone) ; fichiers en `chmod +x` |
| `ruff: command not found` dans le hook | Activer le `.venv` (le hook ignore ruff s'il est absent) |
| `Author identity unknown` | `git config user.name` / `user.email` |
| Secret réellement poussé | Le **révoquer**, en créer un nouveau ; supprimer le commit ne suffit pas |

---

## Étape 3 — Le script `scripts/check.sh` (2 pts) ✅

**Objectif** : un contrôle qui renvoie **0**, **1** ou **2**, testé en succès et en échec. La CI et le hook l'utilisent.

```bash
./scripts/check.sh; echo "Code de sortie: $?"                 # attendu : 0

# Échec 1 : un fichier manquant
mv src/pretlab/main.py /tmp/main.py.bak
./scripts/check.sh; echo "Code de sortie: $?"                 # attendu : 1
mv /tmp/main.py.bak src/pretlab/main.py

# Échec 2 : le port 5432 de la base publié
cp compose.yaml /tmp/compose.bak
sed -i 's#^    volumes:#    ports:\n      - "5432:5432"\n    volumes:#' compose.yaml
./scripts/check.sh; echo "Code de sortie: $?"                 # attendu : 1
cp /tmp/compose.bak compose.yaml

# Échec 3 : un .env suivi par Git
echo 'X=1' > .env && git add -f .env
./scripts/check.sh; echo "Code de sortie: $?"                 # attendu : 1
git rm --cached .env && rm .env

./scripts/check.sh --zzz; echo "Code de sortie: $?"           # attendu : 2 (option inconnue)
./scripts/check.sh; echo "Code de sortie: $?"                 # retour à 0
git status --short                                            # attendu : rien
```

**À observer** : en succès, des lignes vertes `[OK]` puis `[SUCCES]` et `0`. En échec, des lignes rouges `[ERREUR] ...` (sur la sortie d'erreur), `[ECHEC] N erreur(s)` et `1`.

**Ce que contrôle le script** : fichiers obligatoires et scripts exécutables ; aucun secret évident ; aucun `.env` suivi ; Dockerfile (multi-stage, tags explicites sans `latest`, utilisateur final non root, `HEALTHCHECK`, labels OCI) ; Compose (port 5432 non publié, `service_healthy`, pas de `latest`, **aucun `build:` en staging**) ; `shellcheck` s'il est installé.

**Codes de sortie** : `0` tout va bien · `1` un contrôle échoue · `2` mauvais usage ou hors d'un dépôt Git. La CI ne lit que ce chiffre.

**Pourquoi `set -euo pipefail`** : `-e` s'arrête à la première commande en échec ; `-u` refuse une variable non définie (faute de frappe) ; `pipefail` fait échouer un enchaînement `a | b` si `a` échoue.

| Erreur | Correction |
|---|---|
| `Permission denied` | `chmod +x scripts/*.sh scripts/hooks/*` |
| `bad interpreter` / `^M` | Fins de ligne CRLF : `sed -i 's/\r$//' scripts/*.sh` (`.gitattributes` les force en LF) |
| Le script affiche OK alors qu'il devrait échouer | Toujours **tester l'échec** (faute de frappe dans la liste) |

---

## Étape 4 — Lint et tests en local (✅ unitaires, 🖥️ intégration)

```bash
. .venv/bin/activate
make lint                       # ruff : style
make test                       # pytest + tests du script de déploiement
```

**À observer** : `All checks passed!`, puis `12 passed, 4 skipped` (les 4 tests « intégration » sont ignorés sans base), puis `Résultat : 18 réussis, 0 échec(s)`.

**Tests contre une vraie base** (🖥️, facultatif mais recommandé) :

```bash
docker run -d --name pg-test -e POSTGRES_PASSWORD=test-fictif -e POSTGRES_USER=test -e POSTGRES_DB=test \
  -p 127.0.0.1:55432:5432 postgres:17-alpine
sleep 5
PRETLAB_TEST_DSN="host=127.0.0.1 port=55432 dbname=test user=test password=test-fictif" pytest -q
docker rm -f pg-test
```

**À observer** : `16 passed` (aucun skipped). *À la création, ces 4 tests d'intégration ont été exécutés avec succès sur un PostgreSQL 16 embarqué ; sur ta machine ils tournent sur la 17.*

**Pourquoi** : les tests unitaires (base en mémoire) sont instantanés ; les tests d'intégration prouvent que le SQL et l'index unique partiel fonctionnent vraiment. La CI exécute les deux.

| Erreur | Correction |
|---|---|
| `ModuleNotFoundError: pretlab` | Lancer `pytest` depuis la racine (`pythonpath = ["src"]` est dans `pyproject.toml`) |
| `connection refused` (intégration) | Base pas encore prête : attendre quelques secondes, vérifier le port |

---

## Étape 5 — Dockerfile multi-stage (3 pts) 🖥️

**Objectif** : une image petite, non root, avec HEALTHCHECK et labels.

```bash
docker build -t pretlab:1.0-local --build-arg VERSION=1.0-local --build-arg REVISION="$(git rev-parse --short HEAD)" .
docker image ls pretlab
docker run -d --name pretlab-seul -p 8080:8080 pretlab:1.0-local
curl -fsS http://localhost:8080/health          # 200, JSON avec status ok
curl -fsS http://localhost:8080/version         # version et commit gravés dans l'image
curl -s -o /dev/null -w "%{http_code}\n" http://localhost:8080/ready    # 503 : pas de base ici, c'est NORMAL
docker exec pretlab-seul whoami                 # app
sleep 15
docker inspect --format '{{.State.Health.Status}}' pretlab-seul         # healthy
docker inspect --format '{{json .Config.Labels}}' pretlab-seul          # labels OCI
docker history pretlab:1.0-local
docker rm -f pretlab-seul
```

**À observer** : `/health` répond, `/ready` répond **503** (seul, le conteneur n'a pas sa base), `whoami` affiche `app`, l'état devient `healthy`, les labels contiennent `org.opencontainers.image.version` et `.revision`.

**Test du cache** :

```bash
printf '\n# test\n' >> src/pretlab/main.py
docker build -t pretlab:1.0-local .             # la couche « pip install » est CACHED
git checkout -- src/pretlab/main.py
```

**Pourquoi chaque choix**

| Élément | Raison |
|---|---|
| **Multi-stage** (`builder` puis `runtime`) | Les outils d'installation restent dans l'étape jetable ; seule la venv est copiée |
| `python:3.12.8-slim-bookworm` | Tag précis (jamais `latest`), image légère |
| `COPY requirements.txt` + `pip install` avant `COPY src/` | Les dépendances changent rarement → cache réutilisé |
| `ARG VERSION/REVISION` → `ENV` et `LABEL` | La version est gravée **une fois**, à la construction par la CI ; l'image ne change plus |
| `useradd --system app` + `USER app` | Un attaquant n'obtient pas root dans le conteneur |
| `HEALTHCHECK` Python sur `127.0.0.1` | Pas de `curl` dans l'image slim ; `127.0.0.1` est correct *dans* le conteneur |
| `--bind 0.0.0.0:8080` | `127.0.0.1` rendrait le service injoignable de l'extérieur |
| `.dockerignore` | `.git`, `.env`, tests, scripts n'entrent pas dans l'image |
| `gunicorn` | Vrai serveur de production (2 workers), pas le serveur de développement |

| Erreur | Correction |
|---|---|
| `port is already allocated` | `docker ps` puis arrêter le conteneur fautif |
| `Connection reset by peer`, conteneur « Up » | L'application écoute sur `127.0.0.1` : remettre `0.0.0.0`, reconstruire |
| `COPY failed: file not found` | Fichier exclu par `.dockerignore` ou mauvais chemin |
| Code modifié sans effet | Une image est immuable : **reconstruire** |

---

## Étape 6 — Compose : API + PostgreSQL (3 pts) ✅ `config` / 🖥️ le reste

**Objectif** : **une commande** démarre la pile ; réseau privé, volume, santé.

```bash
make up                                   # crée .env, construit, démarre, ATTEND que tout soit sain
docker compose config -q && echo "configuration valide"
docker compose ps                         # api et db « healthy »
curl -fsS http://localhost:8080/ready
```

**À observer** : `db` devient `healthy` **avant** que `api` démarre ; `/ready` répond 200. *Sans `.env`, `docker compose config` échoue avec le message « copiez .env.example vers .env » (✅ vérifié) ; `make up` crée le fichier pour toi.*

**Preuve 1 — connexion par nom de service**

```bash
docker compose exec api python -c "import socket; print(socket.gethostbyname('db'))"   # une IP privée
curl -fsS -X POST -H 'Content-Type: application/json' -d '{"name":"Carte Arduino","tag":"ARD-001"}' http://localhost:8080/equipment
curl -fsS -X POST -H 'Content-Type: application/json' -d '{"equipment_id":1,"borrower":"Amel","days":7}' http://localhost:8080/loans
curl -s -o /dev/null -w "second prêt -> HTTP %{http_code}\n" -X POST -H 'Content-Type: application/json' \
  -d '{"equipment_id":1,"borrower":"Sami"}' http://localhost:8080/loans       # 409
```

**Preuve 2 — le port 5432 n'est pas publié**

```bash
docker compose ps                                       # seul 8080 apparaît côté hôte
docker compose port db 5432 || echo "5432 non publié (voulu)"
ss -ltn | grep ':5432' || echo "rien n'écoute sur 5432 côté hôte"
```

**Preuve 3 — persistance (volume nommé)**

```bash
curl -fsS 'http://localhost:8080/loans?active=true'        # noter le prêt d'Amel
docker compose down                                      # supprime conteneurs + réseau, PAS le volume
docker volume ls | grep pgdata                           # le volume existe toujours
make up
curl -fsS 'http://localhost:8080/loans?active=true'        # le MÊME prêt est toujours là
```

**Pourquoi**

- Sur le réseau Compose, **le nom du service est un nom de machine** : l'API joint la base par `db`. `localhost` depuis `api` désigne `api` lui-même.
- `depends_on` seul n'attend pas que PostgreSQL soit *prêt* : `condition: service_healthy` + `pg_isready` règle la course. `--wait` fait attendre `make up` jusqu'à la santé.
- Un volume nommé survit à `down` ; **`down -v` détruit les données** (`make reset` demande confirmation).
- Les identifiants viennent de `.env` (ignoré) ; `${VAR:?message}` échoue clairement s'ils manquent.

| Erreur | Correction |
|---|---|
| `required variable ... is missing` | `.env` absent : `make env` |
| `port is already allocated` (8080) | `docker rm -f pretlab-seul` ou changer `API_PORT` dans `.env` |
| `password authentication failed` | Le volume garde l'ancien mot de passe (les `POSTGRES_*` ne s'appliquent qu'à la 1re initialisation) → `make reset`, en connaissance de cause |
| Erreur YAML | Indentation (espaces, pas de tabulation) ; relire `docker compose config` |
| Données disparues | `down -v` ou `make reset` exécuté |

---

## Étape 7 — Publier sur GitHub 🖥️

```bash
# github.com : New repository > nom "pretlab" > SANS README, SANS .gitignore, SANS licence
# (dépôt public recommandé : package public et protection de branche disponibles)
git remote add origin https://github.com/TON-UTILISATEUR/pretlab.git
git remote -v
git push -u origin main
git push origin feature/overdue-loans demo/pr-rouge
```

**Authentification** : jamais le mot de passe du compte. Utilise `gh auth login`, une clé SSH, ou un jeton personnel saisi **sans l'écrire dans une commande enregistrée**.

**À observer** : onglet **Actions** : le workflow **CI** tourne sur le push vers `main` (vert attendu). Les deux branches apparaissent dans *Branches*.

**Dans le Dockerfile**, `SOURCE=https://github.com/OWNER/pretlab` n'est qu'une valeur par défaut ; la CI la remplace par ton vrai dépôt.

| Erreur | Correction |
|---|---|
| `remote origin already exists` | `git remote set-url origin <url>` |
| `src refspec main does not match any` | `git branch --show-current` (branche `master` ?) |
| `Updates were rejected` | Dépôt distant non vide (README créé depuis l'interface) : repartir d'un dépôt vide |

---

## Étape 8 — Pipeline CI : une PR verte, une PR rouge (3 pts) 🖥️

La CI (`.github/workflows/ci.yml`) a quatre jobs : `lint`, `test (3.11)`, `test (3.12)`, `docker-build`. `docker-build` exige `needs: [lint, test]`. Permissions : `contents: read` seulement.

### 8.1 PR verte (reste **ouverte** jusqu'à l'étape 11)

Sur GitHub : **Compare & pull request**, base `main`, compare `feature/overdue-loans`. Le modèle de PR s'affiche : remplis-le.

```markdown
## Objectif
Lister les prêts dont l'échéance est dépassée.
## Changements
- GET /loans/overdue
- tests mémoire + PostgreSQL
## Vérification
- [x] make test et make lint passent en local
- [x] scripts/check.sh renvoie 0
- [x] aucun secret ajouté
## Impact sur la mise en service
Aucune nouvelle variable ni migration. Retour arrière sans risque (route ajoutée seulement).
```

Laisse un commentaire de relecture utile (ex. : « précise le format de `due_at` dans le README »), corrige si besoin.

**À observer** (onglet *Checks*) : `lint` vert ; `test (3.11)` et `test (3.12)` verts (avec une vraie base PostgreSQL 17 en service) ; **puis** `docker-build` vert, avec son test de fumée (santé + utilisateur `app`). Les artefacts `rapport-tests-py3.11` et `rapport-tests-py3.12` sont téléchargeables.

➡️ Note l'URL de l'exécution : `https://github.com/TON-UTILISATEUR/pretlab/actions/runs/<numéro>` (**URL verte**). **Ne fusionne pas encore.**

### 8.2 PR rouge (jamais fusionnée)

Ouvre une PR depuis `demo/pr-rouge` vers `main` (la branche contient `tests/test_rouge.py`, un échec volontaire).

**À observer** : `lint` vert, `test (3.11)` et `test (3.12)` **rouges**, `docker-build` **ignoré** (skipped) à cause de `needs`. Ouvre le job rouge, étape `Run pytest -q ...` : la **première erreur utile** est le bloc `E   AssertionError: pipeline rouge de démonstration` / `E   assert 1 == 2` et la ligne `FAILED tests/test_rouge.py::test_echec_volontaire`. **Pas** la dernière ligne `Process completed with exit code 1`, qui dit seulement qu'une commande a rendu un code non nul. Le rapport `report.xml` est quand même conservé (`if: always()`).

Ferme la PR **sans fusionner**. L'URL de cette exécution est ton **URL rouge**.

**Pourquoi** : le runner est une machine neuve qui ne connaît rien de ton poste ; tout doit être déclaré dans le dépôt. `needs` empêche de construire une image dont les tests échouent.

| Erreur | Correction |
|---|---|
| Aucun pipeline ne démarre | Fichier hors de `.github/workflows/`, ou YAML invalide (l'onglet Actions l'indique) |
| `lint` rouge : `ruff format --check` | Lancer `ruff format .` en local, recommiter |
| `lint` rouge : `check.sh` | Lire la ligne `[ERREUR]` : elle dit quoi corriger |
| Tests verts en local, rouges en CI | Dépendance non déclarée : recréer un `.venv` vide, réinstaller |
| `test` rouge sur la base | Service `postgres` du workflow mal configuré : lire le bloc *Initialize containers* |

---

## Étape 9 — Version immuable v1.0.0 et image publiée (2 pts) 🖥️

### 9.1 Tagger depuis `main` (sans `/loans/overdue`)

```bash
git switch main && git pull --ff-only origin main
./scripts/check.sh && pytest -q
git tag -a v1.0.0 -m "Release 1.0.0"
git show v1.0.0 --stat | head -8
git push origin v1.0.0
```

Le workflow **Release** (`release.yml`, déclenché par `v*.*.*`) enchaîne : `ci` (la CI complète, réutilisée) → `publish` (construit **une seule fois** l'image et la pousse sur `ghcr.io/<proprietaire>/pretlab:v1.0.0`, avec version, commit et source gravés) → `deploy-staging` (bonus, étape 13.2).

**À observer** : Actions → **Release** vert ; ton profil → *Packages* → `pretlab` avec le tag `v1.0.0` ; le résumé de l'exécution affiche l'empreinte (digest) de l'image.

**Rendre le package accessible** (le plus simple) : *Package settings → Change visibility → Public*. Sinon :

```bash
read -rs GHCR_TOKEN          # colle un jeton (read:packages) puis Entrée : rien ne s'affiche
echo "$GHCR_TOKEN" | docker login ghcr.io -u TON-UTILISATEUR --password-stdin
unset GHCR_TOKEN
```

**Pourquoi** : un tag publié **ne bouge jamais** (si la version est mauvaise : `v1.0.1`). L'image de `v1.0.0` sera déployée **et** celle vers laquelle on reviendra : on ne la reconstruit jamais.

| Erreur | Correction |
|---|---|
| Push d'image refusé (403) | `permissions: packages: write` présent ? nom de propriétaire en minuscules ? |
| `tag invalide` | Le tag doit être exactement `vX.Y.Z` |
| Le workflow ne démarre pas | `git push origin v1.0.0` (un `git push` simple ne pousse pas les tags) |

---

## Étape 10 — Mise en service en staging avec `deploy.sh` 🖥️

```bash
make down                                  # libérer le port 8080
mkdir -p ~/devops-l3/projet/preuves

printf 'POSTGRES_DB=pretlab\nPOSTGRES_USER=pretlab\nPOSTGRES_PASSWORD=staging-local-fictif\n' > .env.staging
export IMAGE_REPO=ghcr.io/TON-UTILISATEUR-EN-MINUSCULES/pretlab
git check-ignore -v .env.staging .env.deploy .deploy-state     # tous ignorés

./scripts/deploy.sh v1.0.0 | tee ~/devops-l3/projet/preuves/staging-v1.0.0.txt
curl -fsS http://localhost:8080/version
```

**À observer** : `deploy.sh` fait `pull` puis `up -d` (**aucun build**), appelle `wait-healthy.sh v1.0.0`, puis affiche `[SUCCES] v1.0.0 en service ... (durée Ns)`. `/version` répond `"version":"v1.0.0"` avec le commit de l'image.

**Ce que fait `deploy.sh`** : vérifie le format du tag, écrit `.env.deploy` (`IMAGE_REPO`, `IMAGE_TAG`), tire l'image publiée, démarre, **attend que `/ready` réponde ET que `/version` affiche le bon tag**, mémorise `CURRENT`/`PREVIOUS` dans `.deploy-state`. Si la santé échoue : journaux affichés, code de sortie 1 (et retour arrière automatique avec `--auto-rollback`). Sa logique a été testée (✅) avec un docker simulé : `./tests/shell/test_deploy.sh`.

**Pourquoi** : une commande de déploiement qui réussit ne prouve pas que l'application répond. Seul le contrôle de santé fait foi, **et** la version affichée prouve que c'est bien l'image attendue qui tourne.

| Erreur | Correction |
|---|---|
| `IMAGE_REPO non défini` | `export IMAGE_REPO=ghcr.io/...` (minuscules) |
| `.env.staging absent` | Le créer (commande ci-dessus) |
| `manifest unknown` | Tag absent du registre : vérifier la publication (étape 9) |
| `unauthorized` / `denied` au `pull` | Package privé : le rendre public ou `docker login ghcr.io` |
| `port is already allocated` | `make down` sur la pile de développement |

---

## Étape 11 — Publier la v1.1.0 🖥️

Sur GitHub, **fusionne la PR verte** `feature/overdue-loans` (bouton *Merge*), puis :

```bash
git switch main && git pull --ff-only origin main
git log --oneline -n 4
git tag -a v1.1.0 -m "Release 1.1.0"
git push origin v1.1.0
```

Attends le workflow **Release** vert (image `:v1.1.0` publiée, une seule fois). Puis :

```bash
./scripts/deploy.sh v1.1.0 | tee ~/devops-l3/projet/preuves/staging-v1.1.0.txt
curl -fsS http://localhost:8080/version                      # v1.1.0
curl -s -o /dev/null -w "GET /loans/overdue -> HTTP %{http_code}\n" http://localhost:8080/loans/overdue   # 200
```

**À observer** : `"version":"v1.1.0"` et la route `/loans/overdue` répond **200**. Dans `deploy.sh`, `(version en service avant : v1.0.0)`.

---

## Étape 12 — Retour arrière vers v1.0.0 (1 pt) 🖥️

**Scénario** : v1.1.0 est en service ; on décide de revenir à la version précédente.

```bash
time ./scripts/deploy.sh --previous 2>&1 | tee ~/devops-l3/projet/preuves/rollback-v1.0.0.txt
curl -fsS http://localhost:8080/version
curl -s -o /dev/null -w "GET /loans/overdue -> HTTP %{http_code}\n" http://localhost:8080/loans/overdue   # 404
curl -fsS http://localhost:8080/loans                        # les données sont intactes (volume)
docker compose --env-file .env.deploy -f compose.staging.yaml images
cat .deploy-state
```

*(Équivalent explicite : `./scripts/deploy.sh v1.0.0`.)*

**À observer** : `[SUCCES] v1.0.0 en service` ; `/version` → `v1.0.0` ; `/loans/overdue` → **404** (la route n'existe pas dans v1.0.0) ; aucun *build* nulle part ; `real` de `time` = durée du retour arrière ; `.deploy-state` : `CURRENT=v1.0.0`, `PREVIOUS=v1.1.0`.

**Pourquoi** : revenir en arrière = **redéployer un tag déjà publié et validé**. On ne reconstruit jamais pendant un incident : reconstruire, c'est introduire une inconnue au pire moment. Les données PostgreSQL survivent (volume `pgdata-staging`).

**Variante `--auto-rollback`** : `./scripts/deploy.sh v1.2.0 --auto-rollback` revient seul à la version en service si le contrôle de santé échoue, et renvoie quand même `1` pour que la CI sache que le déploiement demandé a échoué. (Testé avec un docker simulé ; pour l'essayer en vrai il faut une image défectueuse, par exemple celle fournie par l'enseignant.)

---

## Étape 13 — Bonus (seulement après les 7 essentiels)

### 13.1 Protection de `main` (+1) 🖥️
GitHub → *Settings → Branches → Add branch protection rule* (ou *Rules → Rulesets*) sur `main` : **Require a pull request before merging** + **Require status checks to pass** avec `lint`, `test (3.11)`, `test (3.12)`, `docker-build` (ils n'apparaissent qu'après une première exécution). Ne coche pas « Require approvals » : tu es seul.
**Preuve** : rouvre la PR rouge : le bouton de fusion est **bloqué** ; capture d'écran. *Selon le type de dépôt/forfait, un dépôt public convient.*

### 13.2 Déploiement automatique sur tag (+2) 🖥️
Déjà dans `release.yml` : après `publish`, le job `deploy-staging` appelle **le même `scripts/deploy.sh`** que toi, puis le contrôle de santé valide la version. **Preuve** : l'exécution **Release** avec ses trois blocs verts (`ci`, `publish`, `deploy-staging`). *Limite honnête* : ce staging vit sur le runner GitHub, éphémère ; ton staging local reste celui des étapes 10-12.

### 13.3 Matrice de versions (+1) 🖥️
Déjà dans `ci.yml` (`python: ['3.11','3.12']`, `fail-fast: false`). **À expliquer** : deux jobs indépendants ; si 3.11 échoue, 3.12 va jusqu'au bout et on voit les deux résultats ; l'image Docker est en 3.12, la 3.11 ne sert qu'à vérifier la compatibilité du code.

### 13.4 Profil Compose de débogage (+1) 🖥️
```bash
make up                                    # adminer NE démarre PAS
docker compose ps                          # adminer absent
make debug                                 # adminer démarre (profil debug)
# navigateur : http://localhost:8081  -> Système: PostgreSQL, Serveur: db, Utilisateur/Mot de passe/Base: voir .env
docker compose --profile debug down
```

### 13.5 Image allégée, avant/après (+1) 🖥️
« Avant » = une construction naïve (image complète, une seule étape, exécutée en root) ; « après » = ton Dockerfile.
```bash
docker build -t pretlab:naive -f - . <<'EOF'
FROM python:3.12.8
WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt
COPY src/pretlab ./pretlab
CMD ["gunicorn", "--bind", "0.0.0.0:8080", "pretlab.main:create_app()"]
EOF
docker build -t pretlab:optimise .
docker image ls pretlab                    # RELEVER les deux tailles
docker history pretlab:naive
docker history pretlab:optimise
```
**À expliquer avec TES chiffres** : l'écart vient de l'image de base (`slim` sans outils de compilation ni paquets inutiles), du multi-stage (seule la venv est livrée), de `--no-cache-dir` (pas de cache pip dans l'image) et de `.dockerignore` (contexte réduit).

### 13.6 Compte rendu d'incident (+1) 🖥️
Provoque une panne réelle : dans `compose.yaml`, remplace `DB_HOST: db` par `DB_HOST: localhost`, puis :
```bash
docker compose up -d --force-recreate api
docker compose ps
docker compose logs --tail=50 api
docker compose exec api env | sort | grep -E 'DB_|POSTGRES_DB'
curl -s -o /dev/null -w "/health -> %{http_code}\n" http://localhost:8080/health
curl -s -o /dev/null -w "/ready  -> %{http_code}\n" http://localhost:8080/ready
curl -s -o /dev/null -w "/loans  -> %{http_code}\n" http://localhost:8080/loans
```
**Ce que tu dois constater, et expliquer** : le conteneur est « Up » et même « healthy » (le HEALTHCHECK de l'image utilise `/health`, la *vivacité*), `/health` répond 200, **mais** `/ready` répond 503 et `/loans` échoue (erreur 500, connexion refusée dans les journaux). C'est pour cela que `wait-healthy.sh` interroge **`/ready`** : la vivacité ne prouve pas que la base est joignable. Corrige (`db`), revalide, puis rédige `docs/incident-01.md` **avec tes propres observations**, via une PR :
```markdown
# Incident 01 — API injoignable vers la base
- Symptôme : (ce que tu as vu : codes HTTP, état Compose)
- Première erreur utile dans les journaux : (copier la ligne)
- Cause : DB_HOST valait localhost au lieu de db
- Correction : (une seule modification + commande de vérification)
- Prévention : (ex. docker compose config avant chaque up ; contrôle sur /ready dans deploy.sh)
```
Reviens ensuite à `DB_HOST: db` (`git checkout -- compose.yaml`).

---

## Étape 14 — Livrables finaux

```bash
git switch main && git pull --ff-only origin main
./scripts/check.sh && make test && make lint && git status
git log --oneline --graph --decorate --all -n 25
git tag -n
```

À rendre : dépôt Git avec `README.md` (démarrage en **une commande** : `make up`) ; **URL d'une exécution verte** et **URL d'une exécution rouge** (voir `URLS_PIPELINES.md`) ; `FICHE_1_PAGE.md` à jour (version mise en service, déroulé du retour arrière). `TABLEAU_CONFORMITE.md` t'aide à t'auto-contrôler.

---

## Annexe A — Équivalent GitLab CI (non testé)

À utiliser seulement si GitLab est exigé : `.gitlab-ci.yml` à la racine.

```yaml
stages: [lint, test, build]

lint:
  stage: lint
  image: python:3.12-slim
  script:
    - pip install -r requirements-dev.txt
    - ruff check .
    - ruff format --check .
  rules:
    - if: $CI_PIPELINE_SOURCE == "merge_request_event"
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH

test:
  stage: test
  image: python:3.12-slim
  script:
    - pip install -r requirements-dev.txt
    - pytest -q --junitxml=report.xml
  artifacts:
    when: always
    paths: [report.xml]
    reports:
      junit: report.xml
  rules:
    - if: $CI_PIPELINE_SOURCE == "merge_request_event"
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH

docker-build:
  stage: build
  needs: [lint, test]
  image: docker:27
  services: [docker:27-dind]
  script:
    - docker build -t pretlab:ci .
  rules:
    - if: $CI_PIPELINE_SOURCE == "merge_request_event"
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH
```

Correspondances : *pull request* → *merge request* ; `ghcr.io/<owner>` → `$CI_REGISTRY_IMAGE` ; `GITHUB_TOKEN` → `$CI_REGISTRY_USER` / `$CI_REGISTRY_PASSWORD` ; publication sur tag via `rules: - if: $CI_COMMIT_TAG`. Les tests d'intégration demanderaient un bloc `services: [postgres:17-alpine]`.

## Annexe B — Méthode de diagnostic (à réciter en soutenance)

1. Observer l'état sans rien modifier (`docker compose ps`, `docker ps -a`, `git status`).
2. Lire les journaux, retenir la **première** erreur utile, pas la dernière.
3. Comparer configuration attendue et **effective** (`docker compose config`, `exec ... env`).
4. Formuler une hypothèse vérifiable.
5. Appliquer **une seule** correction, puis revalider.

## Annexe C — Ce qui a été vérifié à la création du dépôt

| Élément | Résultat | Limites |
|---|---|---|
| `pytest` unitaires | 12 réussis sur `main` (14 sur la branche `feature/overdue-loans`) | |
| Tests d'intégration SQL | 4 réussis sur `main` (5 sur la branche feature) | PostgreSQL **16** embarqué, pas la 17 de la pile |
| Test HTTP de bout en bout | gunicorn, 2 workers, vraie base : `/health`, `/version`, `/ready`, création, 1er prêt 201, 2e prêt 409 | |
| `ruff check` / `ruff format --check` | propres | |
| `shellcheck` 0.11.0 | propre sur tous les scripts | |
| `actionlint` 1.7.12 | propre sur les 2 workflows | |
| `scripts/check.sh` | 0 en succès ; 1 pour Dockerfile root/latest/sans HEALTHCHECK, port 5432 publié, `.env` suivi, jeton factice ; 2 pour option inconnue | |
| `tests/shell/test_deploy.sh` | 18 assertions réussies | **docker simulé** : teste la logique et les codes de sortie, pas un vrai déploiement |
| Hooks `commit-msg` / `pre-commit` | message hors convention refusé ; tous les commits du dépôt sont passés par les hooks | |
| `docker compose config` | `compose.yaml` et `compose.staging.yaml` valides, `adminer` seulement avec `--profile debug`, message clair sans `.env` | pas de démon : aucun conteneur lancé |
| **Non exécuté** | `docker build`, `docker compose up`, HEALTHCHECK réel, GitHub Actions, ghcr.io, staging, retour arrière réel | à faire sur ta machine (🖥️) |
