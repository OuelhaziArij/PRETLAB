#!/usr/bin/env bash
# Met en service une version PUBLIÉE (jamais de build) ou revient à la précédente.
#
# Usage :
#   scripts/deploy.sh v1.1.0                  déployer la version v1.1.0
#   scripts/deploy.sh v1.0.0                  « rollback » = redéployer une ancienne version
#   scripts/deploy.sh --previous              revenir automatiquement à la version précédente
#   scripts/deploy.sh v1.1.0 --auto-rollback  si le contrôle de santé échoue, revenir en arrière
#
# Variables : IMAGE_REPO (ex. ghcr.io/utilisateur/pretlab, sinon lu dans .env.deploy)
#             COMPOSE_FILE (défaut compose.staging.yaml), STATE_FILE (défaut .deploy-state)
# Codes de sortie : 0 déployé et sain, 1 échec de mise en service ou de santé, 2 usage/configuration.
set -euo pipefail

COMPOSE_FILE="${COMPOSE_FILE:-compose.staging.yaml}"
STATE_FILE="${STATE_FILE:-.deploy-state}"
DOCKER="${DOCKER:-docker}"
WAIT_HEALTHY="${WAIT_HEALTHY:-scripts/wait-healthy.sh}"
ENV_DEPLOY=".env.deploy"

die() { echo "[ERREUR] $1" >&2; exit "${2:-2}"; }
state_get() { [[ -f "$STATE_FILE" ]] && grep -E "^$1=" "$STATE_FILE" | cut -d= -f2 || true; }

tag=""; use_previous=0; auto_rollback=0
for arg in "$@"; do
  case "$arg" in
    --previous) use_previous=1 ;;
    --auto-rollback) auto_rollback=1 ;;
    -h|--help) sed -n '2,14p' "$0"; exit 0 ;;
    -*) die "option inconnue : $arg" ;;
    *) tag="$arg" ;;
  esac
done

current="$(state_get CURRENT)"
previous="$(state_get PREVIOUS)"

if [[ $use_previous -eq 1 ]]; then
  [[ -n "$previous" ]] || die "aucune version précédente connue (voir $STATE_FILE)"
  tag="$previous"
fi
[[ -n "$tag" ]] || die "indiquez une version : scripts/deploy.sh vX.Y.Z (ou --previous)"
[[ "$tag" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "version invalide « $tag » (attendu : vX.Y.Z)"

if [[ -z "${IMAGE_REPO:-}" && -f "$ENV_DEPLOY" ]]; then
  IMAGE_REPO="$(grep -E '^IMAGE_REPO=' "$ENV_DEPLOY" | cut -d= -f2 || true)"
fi
[[ -n "${IMAGE_REPO:-}" ]] || die "IMAGE_REPO non défini (ex. export IMAGE_REPO=ghcr.io/utilisateur/pretlab)"
[[ -f .env.staging ]] || die "fichier .env.staging absent (voir GUIDE_COMMANDES.md, étape staging)"

printf 'IMAGE_REPO=%s\nIMAGE_TAG=%s\n' "$IMAGE_REPO" "$tag" > "$ENV_DEPLOY"
compose() { "$DOCKER" compose --env-file "$ENV_DEPLOY" -f "$COMPOSE_FILE" "$@"; }

echo "[DEPLOY] $IMAGE_REPO:$tag  (version en service avant : ${current:-aucune})"
SECONDS=0
compose pull
compose up -d

if "$WAIT_HEALTHY" "$tag"; then
  if [[ "$tag" != "$current" ]]; then
    printf 'CURRENT=%s\nPREVIOUS=%s\n' "$tag" "$current" > "$STATE_FILE"
  fi
  echo "[SUCCES] $tag en service, contrôle de santé validé (durée ${SECONDS}s)"
  exit 0
fi

echo "[ECHEC] contrôle de santé négatif pour $tag" >&2
compose logs --tail=50 api >&2 || true
if [[ $auto_rollback -eq 1 && -n "$current" && "$current" != "$tag" ]]; then
  echo "[ROLLBACK] retour automatique vers $current" >&2
  "$0" "$current" || echo "[ERREUR] le retour arrière a lui aussi échoué" >&2
fi
# Code 1 même si le retour arrière a réussi : le déploiement demandé, lui, a échoué.
exit 1
