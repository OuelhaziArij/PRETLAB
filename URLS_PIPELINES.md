# Les deux URLs de pipeline à fournir

Je n'ai pas pu exécuter GitHub Actions depuis l'environnement de création : **ces URLs n'existent qu'après tes propres exécutions**. Aucune URL n'est inventée ici.

| Pipeline | À fournir | Comment le produire (détail : GUIDE_COMMANDES.md, étape 8) |
|---|---|---|
| 🟢 **Vert** | URL d'une exécution réussie | PR `feature/overdue-loans` → `main` : `lint`, `test (3.11)`, `test (3.12)` verts, puis `docker-build` vert |
| 🔴 **Rouge** | URL d'une exécution en échec | PR `demo/pr-rouge` → `main` (contient `tests/test_rouge.py`, un échec volontaire), fermée sans fusion |

## Récupérer l'URL exacte

1. Onglet **Actions** du dépôt → clique l'exécution voulue.
2. Copie l'adresse du navigateur : `https://github.com/<utilisateur>/pretlab/actions/runs/<numéro>`.
3. Pour la rouge, ouvre le job en échec, étape `Run pytest` : surligne la **première erreur utile** (`E   AssertionError: pipeline rouge de démonstration` et `FAILED tests/test_rouge.py::test_echec_volontaire`) dans ta capture : c'est une preuve demandée.

## À consigner ici une fois produites

- URL verte : https://github.com/OuelhaziArij/PRETLAB/actions/runs/45035143406
- URL rouge : https://github.com/OuelhaziArij/PRETLAB/actions/runs/45036483436
- (bonus) Release de `v1.0.0` (`ci`, `publish`, `deploy-staging` verts) : https://github.com/OuelhaziArij/PRETLAB/actions/runs/45038846007
- Garde les PR, branches et exécutions en ligne jusqu'à la soutenance : ne supprime rien.
