#!/usr/bin/env bash
# Teste la LOGIQUE de scripts/deploy.sh avec un docker SIMULÉ (aucun conteneur lancé).
# Ce n'est pas un vrai déploiement : c'est un test de l'enchaînement, de l'état et des codes de sortie.
set -euo pipefail

repo="$(cd "$(dirname "$0")/../.." && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
cd "$work"
mkdir scripts bin
cp "$repo/scripts/deploy.sh" scripts/
touch .env.staging

# docker simulé : journalise les appels
cat > bin/docker <<'STUB'
#!/usr/bin/env bash
echo "$*" >> "$STUB_LOG"
STUB
# wait-healthy simulé : échoue pour la version $FAIL_TAG
cat > scripts/wait-healthy.sh <<'STUB'
#!/usr/bin/env bash
[[ "${1:-}" == "${FAIL_TAG:-}" ]] && exit 1
exit 0
STUB
chmod +x bin/docker scripts/*.sh
export STUB_LOG="$work/docker.log" DOCKER="$work/bin/docker" IMAGE_REPO="ghcr.io/demo/pretlab"
: > "$STUB_LOG"

pass=0; fails=0
t() { # t "description" attendu_code commande...
  local desc="$1" want="$2"; shift 2
  local got=0; "$@" >/dev/null 2>&1 || got=$?
  if [[ "$got" == "$want" ]]; then echo "[OK] $desc"; pass=$((pass + 1)); else echo "[ECHEC] $desc (code $got, attendu $want)"; fails=$((fails + 1)); fi
}
state() { grep -E "^$1=" .deploy-state | cut -d= -f2; }
eq() {
  if [[ "$1" == "$2" ]]; then echo "[OK] $3"; pass=$((pass + 1)); else echo "[ECHEC] $3 ($1 != $2)"; fails=$((fails + 1)); fi
}

t "version invalide refusée (code 2)" 2 scripts/deploy.sh 1.0
t "sans argument (code 2)" 2 scripts/deploy.sh
t "--previous sans historique (code 2)" 2 scripts/deploy.sh --previous
t "IMAGE_REPO absent (code 2)" 2 env -u IMAGE_REPO scripts/deploy.sh v1.0.0

t "déploiement v1.0.0 (code 0)" 0 scripts/deploy.sh v1.0.0
eq "$(state CURRENT)" "v1.0.0" "état : CURRENT=v1.0.0"
t "déploiement v1.1.0 (code 0)" 0 scripts/deploy.sh v1.1.0
eq "$(state CURRENT)" "v1.1.0" "état : CURRENT=v1.1.0"
eq "$(state PREVIOUS)" "v1.0.0" "état : PREVIOUS=v1.0.0"

t "rollback --previous (code 0)" 0 scripts/deploy.sh --previous
eq "$(state CURRENT)" "v1.0.0" "après rollback : CURRENT=v1.0.0"
eq "$(grep IMAGE_TAG .env.deploy | cut -d= -f2)" "v1.0.0" ".env.deploy pointe vers v1.0.0"

export FAIL_TAG="v1.2.0"
t "version malsaine sans auto-rollback (code 1)" 1 scripts/deploy.sh v1.2.0
eq "$(state CURRENT)" "v1.0.0" "échec : l'état n'est pas modifié"
t "version malsaine avec --auto-rollback (code 1)" 1 scripts/deploy.sh v1.2.0 --auto-rollback
eq "$(grep IMAGE_TAG .env.deploy | cut -d= -f2)" "v1.0.0" "auto-rollback : retour sur v1.0.0"

if grep -qE ' build( |$)' "$STUB_LOG"; then echo "[ECHEC] un build a été lancé"; fails=$((fails + 1)); else echo "[OK] aucun build lancé (image publiée uniquement)"; pass=$((pass + 1)); fi
if grep -q ' pull' "$STUB_LOG" && grep -q ' up -d' "$STUB_LOG"; then
  echo "[OK] pull puis up -d utilisés"; pass=$((pass + 1))
else
  echo "[ECHEC] pull/up manquants"; fails=$((fails + 1))
fi

echo "Résultat : $pass réussis, $fails échec(s)"
[[ $fails -eq 0 ]]
