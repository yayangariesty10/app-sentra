import sys

from pathlib import Path
# supaya modul app di folder src/ bisa di-import
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "src"))
from app import app  # noqa: E402
def client():
    app.config["TESTING"] = True
    return app.test_client()
def test_health_mengembalikan_200():
    r = client().get("/health")
    assert r.status_code == 200
    assert r.get_json()["status"] == "ok"
def test_index_punya_field_wajib():
    data = client().get("/").get_json()
    for field in ("service", "status", "build"):
        assert field in data
def test_endpoint_tidak_dikenal_404():
    assert client().get("/tidak-ada").status_code == 404
