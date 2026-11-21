# DEMO_SOUTENANCE — 10 minutes + questions

## Avant de commencer (à préparer, pas à montrer)

- Deux onglets prêts : la **PR verte** et la **PR rouge** (exécutions terminées, ne rien relancer en direct).
- Staging en **v1.1.0** déjà déployé (`./scripts/deploy.sh v1.1.0`), `IMAGE_REPO` exporté dans le terminal.
- Un terminal dans `pretlab`, port 8080 libre, `.env.staging` présent.
- Les sorties de `~/devops-l3/projet/preuves/` ouvertes en secours.
- Si le réseau lâche : montre les captures et les fichiers de `preuves/`. L'image v1.0.0 est déjà en cache local.

## Déroulé chronométré

| Min | Écran | Ce que tu fais | Ce que tu dis |
|---|---|---|---|
| 0:00–1:00 | `FICHE_1_PAGE.md` (schéma) | Montrer l'architecture | « PrêtLab : une API de prêt de matériel de labo, Flask + PostgreSQL. Le code est minimal ; ce que je présente, c'est la chaîne : du commit à la mise en service, avec retour arrière. » |
| 1:00–3:00 | PR verte | Onglet *Checks* : `lint`, `test (3.11/3.12)`, puis `docker-build` ; ouvrir l'artefact du rapport de tests | « Le pipeline se déclenche sur la pull request. `docker-build` ne démarre qu'après `lint` et les tests grâce à `needs`. Les tests tournent sur une vraie base PostgreSQL. Le rapport est conservé même en cas d'échec grâce à `if: always()`. » |
| 3:00–5:00 | PR rouge | Ouvrir le job `test` en échec, étape `Run pytest` ; surligner `E AssertionError: pipeline rouge de démonstration` / `FAILED tests/test_rouge.py::...` ; montrer `docker-build` ignoré (et le bouton de fusion bloqué si la protection est activée) | « Voici une PR volontairement cassée. L'image n'est pas construite : on ne construit pas ce qui ne passe pas les tests. La **première erreur utile** est cette ligne d'assertion, pas la dernière ligne du journal qui dit seulement qu'une commande a rendu un code non nul. » |
| 5:00–7:00 | Terminal | `git tag -n`, montrer le package ghcr.io `v1.0.0` (digest) ; `curl localhost:8080/version` (v1.1.0 en service) ; `cat scripts/deploy.sh \| head -20` | « Une version = un tag annoté + une image construite **une seule fois** par le workflow Release. Le staging tire cette image avec `deploy.sh`, il ne reconstruit rien. La version affichée par `/version` prouve quelle image tourne. » |
| 7:00–9:00 | Terminal | `curl /loans/overdue` (200) ; `time ./scripts/deploy.sh --previous` ; `curl /version` (v1.0.0) ; `curl /loans/overdue` (404) ; `curl /loans` (données intactes) | « Retour arrière : même script, il redéploie le tag précédent, déjà publié et validé. Le script n'a rendu la main qu'une fois `/ready` joignable **et** la version `v1.0.0` confirmée. La route de la v1.1.0 a disparu, les données sont conservées grâce au volume. » |
| 9:00–10:00 | Dépôt | `git log --oneline --graph`, `./scripts/check.sh` | « Aucun secret n'est versionné, seulement `.env.example` ; un hook bloque les secrets avant le commit. Le script de contrôle renvoie 0, 1 ou 2, et c'est ce code que la CI lit. » |

## 15 questions probables, réponses courtes

1. **Pourquoi `needs` entre les jobs ?** Pour ne construire l'image que si lint et tests passent ; sinon on gaspille du temps et on peut publier du code cassé.
2. **Différence image / conteneur ?** L'image est un modèle immuable en couches ; le conteneur en est une exécution, jetable. On peut lancer autant de conteneurs qu'on veut depuis une image.
3. **Pourquoi un Dockerfile multi-stage ?** L'étape `builder` installe les dépendances ; seule la venv est copiée dans l'image finale, qui reste petite et sans outils inutiles.
4. **Pourquoi pas `latest` ?** C'est un nom par défaut, pas une version : deux machines peuvent exécuter deux contenus différents. Un tag précis identifie une version exacte.
5. **Pourquoi un utilisateur non root ?** Si l'application est compromise, l'attaquant n'a pas les droits root dans le conteneur.
6. **Pourquoi `db` et pas `localhost` ?** Sur le réseau Compose, le nom du service est un nom de machine ; `localhost` depuis `api` désigne `api` lui-même.
7. **Pourquoi ne pas publier le port 5432 ?** Chaque port publié est une porte ouverte ; seule l'API doit joindre la base.
8. **`depends_on` suffit-il ?** Non, il garantit l'ordre de lancement, pas que PostgreSQL soit prêt. D'où `healthcheck` + `condition: service_healthy`.
9. **Que détruit `docker compose down -v` ?** Conteneurs, réseau **et volumes** : les données sont perdues. `down` seul conserve le volume.
10. **Pourquoi `/health` ET `/ready` ?** `/health` dit que le processus tourne (vivacité, utilisé par le HEALTHCHECK) ; `/ready` dit que la base répond. Si `DB_HOST` est faux, `/health` reste 200 mais `/ready` renvoie 503 : c'est `/ready` que `wait-healthy.sh` interroge.
11. **Pourquoi `set -euo pipefail` et des codes de sortie ?** `-e` s'arrête à la première erreur, `-u` refuse une variable non définie, `pipefail` fait échouer un pipe si un maillon échoue. Le code de sortie est la seule chose qu'une machine lit.
12. **Pourquoi ne jamais reconstruire une image de version ?** Une version qui change de contenu rend tout diagnostic impossible ; le retour arrière doit réutiliser une image déjà construite et validée. C'est aussi pourquoi `compose.staging.yaml` n'a aucun `build:`.
13. **Comment fonctionne ton retour arrière ?** `deploy.sh --previous` relit la version précédente dans `.deploy-state`, redéploie ce tag publié, et attend `/ready` et la bonne version. Preuve : `/version` repasse à `v1.0.0`, `/loans/overdue` répond 404.
14. **Livraison continue ou déploiement continu ?** Le pipeline produit automatiquement une version prête (livraison continue) ; ma mise en service locale est déclenchée par une personne. Le bonus sur tag déploie automatiquement vers un staging éphémère, ce qui s'approche du déploiement continu.
15. **Que faire si un secret est poussé ?** Le révoquer et en générer un nouveau immédiatement : le supprimer du dépôt ne suffit pas, l'historique est déjà copié. Mon hook pre-commit bloque les cas évidents avant le commit.

## En cas de problème pendant la démo

| Problème | Réaction |
|---|---|
| `pull` refusé / réseau coupé | Passer aux captures et à `preuves/` ; l'image v1.0.0 est en cache local |
| Port 8080 occupé | `docker ps` puis arrêter l'ancienne pile (`make down`) |
| `deploy.sh` échoue | Lire la dernière ligne `[ERREUR]`/`[ECHEC]` et les journaux affichés ; rester calme : méthode état → journaux → configuration effective → une correction → revérifier |
