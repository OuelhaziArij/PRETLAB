"""Accès aux données : une implémentation en mémoire (tests) et une PostgreSQL."""

from datetime import UTC, datetime, timedelta


class NotFound(Exception):
    """L'objet demandé n'existe pas."""


class Conflict(Exception):
    """L'opération viole une règle métier (déjà prêté, étiquette en double...)."""


def _iso(row):
    """Convertit les dates en texte ISO 8601 pour le JSON."""
    return {k: (v.isoformat() if isinstance(v, datetime) else v) for k, v in row.items()}


class MemoryRepo:
    """Stockage en mémoire : rapide, sans base, utilisé par les tests unitaires."""

    def __init__(self):
        self._equipment = {}
        self._loans = {}

    def ping(self):
        return True

    def _active_loan(self, equipment_id):
        return any(
            ln["equipment_id"] == equipment_id and ln["returned_at"] is None
            for ln in self._loans.values()
        )

    def add_equipment(self, name, tag):
        if any(e["tag"] == tag for e in self._equipment.values()):
            raise Conflict("tag already exists")
        item = {"id": len(self._equipment) + 1, "name": name, "tag": tag}
        self._equipment[item["id"]] = item
        return {**item, "available": True}

    def list_equipment(self):
        return [
            {**e, "available": not self._active_loan(e["id"])} for e in self._equipment.values()
        ]

    def borrow(self, equipment_id, borrower, days):
        if equipment_id not in self._equipment:
            raise NotFound("equipment not found")
        if self._active_loan(equipment_id):
            raise Conflict("equipment already on loan")
        now = datetime.now(UTC)
        loan = {
            "id": len(self._loans) + 1,
            "equipment_id": equipment_id,
            "borrower": borrower,
            "borrowed_at": now,
            "due_at": now + timedelta(days=days),
            "returned_at": None,
        }
        self._loans[loan["id"]] = loan
        return _iso(loan)

    def give_back(self, loan_id):
        loan = self._loans.get(loan_id)
        if loan is None:
            raise NotFound("loan not found")
        if loan["returned_at"] is not None:
            raise Conflict("loan already returned")
        loan["returned_at"] = datetime.now(UTC)
        return _iso(loan)

    def list_loans(self, active_only=False):
        loans = self._loans.values()
        if active_only:
            loans = [ln for ln in loans if ln["returned_at"] is None]
        return [_iso(ln) for ln in loans]


SCHEMA = [
    """CREATE TABLE IF NOT EXISTS equipment (
         id SERIAL PRIMARY KEY,
         name TEXT NOT NULL,
         tag TEXT NOT NULL UNIQUE)""",
    """CREATE TABLE IF NOT EXISTS loans (
         id SERIAL PRIMARY KEY,
         equipment_id INT NOT NULL REFERENCES equipment(id),
         borrower TEXT NOT NULL,
         borrowed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
         due_at TIMESTAMPTZ NOT NULL,
         returned_at TIMESTAMPTZ)""",
    # Règle métier garantie par la base : un seul prêt en cours par objet.
    """CREATE UNIQUE INDEX IF NOT EXISTS one_active_loan_per_item
         ON loans (equipment_id) WHERE returned_at IS NULL""",
]

LOAN_COLS = "id, equipment_id, borrower, borrowed_at, due_at, returned_at"


class PostgresRepo:
    """Stockage PostgreSQL. L'hôte est le NOM DU SERVICE Compose (ex. « db »)."""

    def __init__(self, dsn):
        self.dsn = dsn
        self._ready = False

    def _connect(self):
        import psycopg
        from psycopg.rows import dict_row

        conn = psycopg.connect(self.dsn, row_factory=dict_row)
        if not self._ready:
            # Verrou consultatif : plusieurs workers peuvent démarrer en même temps.
            conn.execute("SELECT pg_advisory_xact_lock(727)")
            for statement in SCHEMA:
                conn.execute(statement)
            conn.commit()
            self._ready = True
        return conn

    def ping(self):
        with self._connect() as conn:
            conn.execute("SELECT 1")
        return True

    def add_equipment(self, name, tag):
        import psycopg

        try:
            with self._connect() as conn:
                row = conn.execute(
                    "INSERT INTO equipment (name, tag) VALUES (%s, %s) RETURNING id, name, tag",
                    (name, tag),
                ).fetchone()
        except psycopg.errors.UniqueViolation as exc:
            raise Conflict("tag already exists") from exc
        return {**row, "available": True}

    def list_equipment(self):
        with self._connect() as conn:
            return conn.execute(
                "SELECT e.id, e.name, e.tag, NOT EXISTS ("
                " SELECT 1 FROM loans l"
                " WHERE l.equipment_id = e.id AND l.returned_at IS NULL"
                ") AS available FROM equipment e ORDER BY e.id"
            ).fetchall()

    def borrow(self, equipment_id, borrower, days):
        import psycopg

        try:
            with self._connect() as conn:
                found = conn.execute(
                    "SELECT 1 FROM equipment WHERE id = %s", (equipment_id,)
                ).fetchone()
                if found is None:
                    raise NotFound("equipment not found")
                row = conn.execute(
                    "INSERT INTO loans (equipment_id, borrower, due_at) "
                    "VALUES (%s, %s, now() + make_interval(days => %s)) "
                    f"RETURNING {LOAN_COLS}",
                    (equipment_id, borrower, days),
                ).fetchone()
        except psycopg.errors.UniqueViolation as exc:
            raise Conflict("equipment already on loan") from exc
        return _iso(row)

    def give_back(self, loan_id):
        with self._connect() as conn:
            row = conn.execute(
                "UPDATE loans SET returned_at = now() "
                f"WHERE id = %s AND returned_at IS NULL RETURNING {LOAN_COLS}",
                (loan_id,),
            ).fetchone()
            if row is None:
                exists = conn.execute("SELECT 1 FROM loans WHERE id = %s", (loan_id,)).fetchone()
                if exists is None:
                    raise NotFound("loan not found")
                raise Conflict("loan already returned")
        return _iso(row)

    def list_loans(self, active_only=False):
        where = "WHERE returned_at IS NULL" if active_only else ""
        with self._connect() as conn:
            rows = conn.execute(f"SELECT {LOAN_COLS} FROM loans {where} ORDER BY id").fetchall()
        return [_iso(r) for r in rows]
