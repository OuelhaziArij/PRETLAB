"""PrêtLab : API de prêt de matériel de laboratoire."""

import os

from flask import Flask, jsonify, request

from pretlab.repo import Conflict, NotFound, PostgresRepo


def dsn_from_env():
    """Construit la connexion PostgreSQL depuis l'environnement (fichier .env)."""
    return (
        f"host={os.getenv('DB_HOST', 'db')} "
        f"port={os.getenv('DB_PORT', '5432')} "
        f"dbname={os.getenv('POSTGRES_DB', 'pretlab')} "
        f"user={os.getenv('POSTGRES_USER', 'pretlab')} "
        f"password={os.getenv('POSTGRES_PASSWORD', '')} "
        "connect_timeout=3"
    )


def create_app(repo=None):
    app = Flask(__name__)
    store = repo if repo is not None else PostgresRepo(dsn_from_env())
    version = os.getenv("APP_VERSION", "dev")
    revision = os.getenv("APP_REVISION", "unknown")

    @app.get("/health")
    def health():
        # Vivacité : le processus répond. Ne dépend volontairement PAS de la base.
        return jsonify(status="ok", version=version)

    @app.get("/version")
    def get_version():
        return jsonify(version=version, revision=revision)

    @app.get("/ready")
    def ready():
        # Disponibilité : la base répond-elle ?
        try:
            store.ping()
        except Exception:  # noqa: BLE001 - toute erreur de base = non prêt
            return jsonify(status="unavailable", version=version), 503
        return jsonify(status="ready", version=version)

    @app.get("/equipment")
    def list_equipment():
        return jsonify(store.list_equipment())

    @app.post("/equipment")
    def add_equipment():
        data = request.get_json(silent=True) or {}
        name = str(data.get("name", "")).strip()
        tag = str(data.get("tag", "")).strip()
        if not name or not tag:
            return jsonify(error="name and tag are required"), 400
        return jsonify(store.add_equipment(name, tag)), 201

    @app.get("/loans")
    def list_loans():
        active = request.args.get("active", "").lower() in ("1", "true", "yes")
        return jsonify(store.list_loans(active_only=active))

    @app.post("/loans")
    def borrow():
        data = request.get_json(silent=True) or {}
        borrower = str(data.get("borrower", "")).strip()
        try:
            equipment_id = int(data.get("equipment_id"))
            days = int(data.get("days", 7))
        except (TypeError, ValueError):
            return jsonify(error="equipment_id and days must be integers"), 400
        if not borrower or not 1 <= days <= 60:
            return jsonify(error="borrower required, days between 1 and 60"), 400
        return jsonify(store.borrow(equipment_id, borrower, days)), 201

    @app.post("/loans/<int:loan_id>/return")
    def give_back(loan_id):
        return jsonify(store.give_back(loan_id))

    @app.errorhandler(NotFound)
    def not_found(exc):
        return jsonify(error=str(exc)), 404

    @app.errorhandler(Conflict)
    def conflict(exc):
        return jsonify(error=str(exc)), 409

    return app
