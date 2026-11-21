import pytest

from pretlab.main import create_app
from pretlab.repo import MemoryRepo


@pytest.fixture
def client():
    return create_app(MemoryRepo()).test_client()


def add_item(client, tag="ARD-001"):
    return client.post("/equipment", json={"name": "Carte Arduino", "tag": tag})


def test_health_and_version(client):
    r = client.get("/health")
    assert r.status_code == 200
    assert r.get_json()["status"] == "ok"
    assert "version" in client.get("/version").get_json()


def test_ready_with_working_store(client):
    assert client.get("/ready").status_code == 200


def test_ready_returns_503_when_store_is_down():
    class BrokenRepo(MemoryRepo):
        def ping(self):
            raise RuntimeError("base injoignable")

    r = create_app(BrokenRepo()).test_client().get("/ready")
    assert r.status_code == 503
    assert r.get_json()["status"] == "unavailable"


def test_add_and_list_equipment(client):
    assert add_item(client).status_code == 201
    items = client.get("/equipment").get_json()
    assert len(items) == 1 and items[0]["available"] is True


def test_duplicate_tag_is_a_conflict(client):
    add_item(client)
    assert add_item(client).status_code == 409


def test_equipment_requires_name_and_tag(client):
    assert client.post("/equipment", json={"name": "x"}).status_code == 400


def test_borrow_makes_item_unavailable(client):
    add_item(client)
    r = client.post("/loans", json={"equipment_id": 1, "borrower": "Amel", "days": 3})
    assert r.status_code == 201
    assert client.get("/equipment").get_json()[0]["available"] is False


def test_cannot_borrow_twice(client):
    add_item(client)
    client.post("/loans", json={"equipment_id": 1, "borrower": "Amel"})
    r = client.post("/loans", json={"equipment_id": 1, "borrower": "Sami"})
    assert r.status_code == 409


def test_borrow_unknown_equipment(client):
    r = client.post("/loans", json={"equipment_id": 99, "borrower": "Amel"})
    assert r.status_code == 404


def test_borrow_validation(client):
    add_item(client)
    assert client.post("/loans", json={"equipment_id": 1}).status_code == 400
    bad = {"equipment_id": 1, "borrower": "A", "days": 999}
    assert client.post("/loans", json=bad).status_code == 400


def test_return_then_borrow_again(client):
    add_item(client)
    loan = client.post("/loans", json={"equipment_id": 1, "borrower": "Amel"}).get_json()
    assert client.post(f"/loans/{loan['id']}/return").status_code == 200
    assert client.post(f"/loans/{loan['id']}/return").status_code == 409
    assert client.post("/loans", json={"equipment_id": 1, "borrower": "Sami"}).status_code == 201


def test_active_filter(client):
    add_item(client)
    loan = client.post("/loans", json={"equipment_id": 1, "borrower": "Amel"}).get_json()
    assert len(client.get("/loans?active=true").get_json()) == 1
    client.post(f"/loans/{loan['id']}/return")
    assert client.get("/loans?active=true").get_json() == []
    assert len(client.get("/loans").get_json()) == 1
