#!/usr/bin/env bash
# Contrôle du projet PrêtLab. Réutilisé par le hook pre-commit et par la CI.
#
# Codes de sortie :
#   0 = tous les contrôles passent
#   1 = au moins un contrôle échoue
#   2 = erreur d'usage ou d'environnement (option inconnue, hors d'un dépôt Git)
set -euo pipefail

if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
  GREEN=$'\033[32m'; RED=$'\033[31m'; YELLOW=$'\033[33m'; BOLD=$'\033[1m'; RESET=$'\033[0m'
else
  GREEN=''; RED=''; YELLOW=''; BOLD=''; RESET=''
fi

errors=0
ok()   { echo "${GREEN}[OK]${RESET}     $1"; }
skip() { echo "${YELLOW}[SKIP]${RESET}   $1"; }
fail() { echo "${RED}[ERREUR]${RESET} $1" >&2; errors=$((errors + 1)); }

usage() {
  cat <<'EOF'
Usage : scripts/check.sh [--secrets-only]
  (sans option)   tous les contrôles
  --secrets-only  seulement la recherche de secrets (utilisé par le hook pre-commit)
Codes de sortie : 0 succès, 1 contrôle en échec, 2 erreur d'usage.
EOF
}

mode="all"
case "${1:-}" in
  "") ;;
  --secrets-only) mode="secrets" ;;
  -h|--help) usage; exit 0 ;;
  *) echo "Option inconnue : $1" >&2; usage >&2; exit 2 ;;
esac

root="$(git rev-parse --show-toplevel 2>/dev/null)" || { echo "Pas dans un dépôt Git" >&2; exit 2; }
cd "$root"

check_secrets() {
  # Motifs assemblés par morceaux pour que ce fichier ne se détecte pas lui-même.
  local key_hdr='-----BEGIN [A-Z ]*PRIV''ATE KEY-----'
  local gh_token='gh[pousr]_[A-Za-z0-9]{36}'
  local aws_key='AKI''A[0-9A-Z]{16}'
  if git grep -InE "($key_hdr|$gh_token|$aws_key)" -- . ':!scripts/check.sh' >/dev/null 2>&1; then
    fail "secret probable trouvé dans un fichier suivi (clé privée, jeton GitHub ou clé AWS)"
  else
    ok "aucun secret évident dans les fichiers suivis"
  fi
  if git ls-files | grep -E '(^|/)\.env($|\.)' | grep -vq '\.env\.example$'; then
    fail "un fichier .env* (hors .env.example) est suivi par Git"
  else
    ok "aucun .env réel suivi (seul .env.example est versionné)"
  fi
}

check_files() {
  local required=(
    README.md .gitignore .env.example .dockerignore Dockerfile Makefile
    compose.yaml compose.staging.yaml requirements.txt requirements-dev.txt pyproject.toml
    src/pretlab/main.py src/pretlab/repo.py tests/test_api.py
    scripts/check.sh scripts/deploy.sh scripts/wait-healthy.sh
    .github/workflows/ci.yml .github/workflows/release.yml
    .github/pull_request_template.md
  )
  local f
  for f in "${required[@]}"; do
    if [[ -f "$f" ]]; then ok "$f"; else fail "fichier absent : $f"; fi
  done
  for f in scripts/*.sh scripts/hooks/*; do
    if [[ -x "$f" ]]; then :; else fail "$f n'est pas exécutable (chmod +x)"; fi
  done
}

check_dockerfile() {
  local from_count
  from_count=$(grep -cE '^FROM ' Dockerfile || true)
  if [[ "$from_count" -ge 2 ]]; then ok "Dockerfile : multi-stage ($from_count étapes)"; else fail "Dockerfile : pas multi-stage"; fi

  if grep -E '^FROM ' Dockerfile | grep -Evq '^FROM [^ :]+:[^ :]+'; then
    fail "Dockerfile : une ligne FROM n'a pas de tag explicite"
  elif grep -E '^FROM ' Dockerfile | grep -Eiq ':latest'; then
    fail "Dockerfile : tag latest interdit"
  else
    ok "Dockerfile : tags explicites (pas de latest)"
  fi

  local last_user
  last_user=$(grep -E '^USER ' Dockerfile | tail -n1 | awk '{print $2}' || true)
  if [[ -n "$last_user" && "$last_user" != "root" && "$last_user" != "0" ]]; then
    ok "Dockerfile : exécution sous l'utilisateur non root « $last_user »"
  else
    fail "Dockerfile : processus final exécuté en root (ajouter USER)"
  fi

  if grep -q '^HEALTHCHECK' Dockerfile; then ok "Dockerfile : HEALTHCHECK présent"; else fail "Dockerfile : HEALTHCHECK absent"; fi
  if grep -q 'org.opencontainers.image.version' Dockerfile && grep -q 'org.opencontainers.image.source' Dockerfile; then
    ok "Dockerfile : labels OCI (version, source)"
  else
    fail "Dockerfile : labels OCI version/source manquants"
  fi
}

check_compose() {
  local f
  for f in compose.yaml compose.staging.yaml; do
    if grep -Eq '^[[:space:]]*-[[:space:]]*["'\'']?[0-9.:]*5432["'\'']?[[:space:]]*$' "$f"; then
      fail "$f : le port 5432 de la base est publié"
    else
      ok "$f : port 5432 non publié"
    fi
    if grep -q 'condition: service_healthy' "$f"; then ok "$f : depends_on conditionné à la santé"; else fail "$f : condition: service_healthy absente"; fi
    if grep -Eq 'image:.*:latest' "$f"; then fail "$f : tag latest interdit"; else ok "$f : aucun tag latest"; fi
  done
  if grep -Eq '^[[:space:]]*build:' compose.staging.yaml; then
    fail "compose.staging.yaml : contient build: (l'image publiée ne se reconstruit jamais)"
  else
    ok "compose.staging.yaml : aucune construction (image publiée uniquement)"
  fi
}

check_shellcheck() {
  if command -v shellcheck >/dev/null 2>&1; then
    if shellcheck scripts/*.sh scripts/hooks/* tests/shell/*.sh; then ok "shellcheck"; else fail "shellcheck a signalé des problèmes"; fi
  else
    skip "shellcheck non installé (facultatif)"
  fi
}

echo "${BOLD}[CHECK] PrêtLab${RESET}"
if [[ "$mode" == "secrets" ]]; then
  check_secrets
else
  check_files
  check_secrets
  [[ -f Dockerfile ]] && check_dockerfile
  [[ -f compose.yaml && -f compose.staging.yaml ]] && check_compose
  check_shellcheck
fi

if [[ $errors -gt 0 ]]; then
  echo "${RED}[ECHEC]${RESET} $errors erreur(s)" >&2
  exit 1
fi
echo "${GREEN}[SUCCES]${RESET} contrôles validés"
