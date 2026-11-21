"""Tests contre une VRAIE base PostgreSQL. Ignorés si PRETLAB_TEST_DSN n'est pas défini."""

import os

import pytest

from pretlab.repo import Conflict, NotFound, PostgresRepo

DSN = os.getenv("PRETLAB_TEST_DSN")
pytestmark = pytest.mark.integration


@pytest.fixture
def repo():
    if not DSN:
        pytest.skip("PRETLAB_TEST_DSN non défini")
    import psycopg

    repo = PostgresRepo(DSN)
    repo.ping()  # crée le schéma
    with psycopg.connect(DSN) as conn:
        conn.execute("TRUNCATE loans, equipment RESTART IDENTITY CASCADE")
    return repo


def test_schema_and_ping(repo):
    assert repo.ping() is True


def test_borrow_rule_enforced_by_database(repo):
    item = repo.add_equipment("Multimètre", "MUL-001")
    repo.borrow(item["id"], "Amel", 3)
    with pytest.raises(Conflict):
        repo.borrow(item["id"], "Sami", 3)


def test_unknown_equipment_and_loan(repo):
    with pytest.raises(NotFound):
        repo.borrow(999, "Amel", 3)
    with pytest.raises(NotFound):
        repo.give_back(999)


def test_full_cycle(repo):
    item = repo.add_equipment("Casque VR", "VR-001")
    with pytest.raises(Conflict):
        repo.add_equipment("Doublon", "VR-001")
    loan = repo.borrow(item["id"], "Amel", 5)
    assert repo.list_equipment()[0]["available"] is False
    assert len(repo.list_loans(active_only=True)) == 1
    done = repo.give_back(loan["id"])
    assert done["returned_at"] is not None
    with pytest.raises(Conflict):
        repo.give_back(loan["id"])
    assert repo.list_equipment()[0]["available"] is True
