.DEFAULT_GOAL := help
export APP_REVISION := $(shell git rev-parse --short HEAD 2>/dev/null || echo local)

.PHONY: help env up down logs ps test lint check hooks debug reset

help: ## Afficher cette aide
	@grep -E '^[a-z-]+:.*## ' $(MAKEFILE_LIST) | awk -F':.*## ' '{printf "  make %-8s %s\n", $$1, $$2}'

env: ## Créer .env depuis .env.example s'il n'existe pas
	@test -f .env || cp .env.example .env

up: env ## Construire et démarrer la pile (API + PostgreSQL) en UNE commande
	docker compose up -d --build --wait
	@echo "PrêtLab démarré : curl http://localhost:$${API_PORT:-8080}/health"

down: ## Arrêter la pile (les données restent dans le volume)
	docker compose down

logs: ## Suivre les journaux de l'API
	docker compose logs -f api

ps: ## État des services
	docker compose ps

debug: env ## Démarrer aussi adminer (http://localhost:8081)
	docker compose --profile debug up -d --build --wait

test: ## Tests unitaires + tests du script de déploiement
	pytest -q
	./tests/shell/test_deploy.sh

lint: ## Vérifier le style du code (ruff)
	ruff check .
	ruff format --check .

check: ## Contrôles du projet (scripts/check.sh)
	./scripts/check.sh

hooks: ## Activer les hooks Git (pre-commit, commit-msg)
	git config core.hooksPath scripts/hooks
	git config commit.template .gitmessage

reset: ## DESTRUCTIF : supprime aussi les données (volume)
	@read -p "Supprimer les conteneurs ET les données ? [oui/N] " r && [ "$$r" = "oui" ]
	docker compose down -v
