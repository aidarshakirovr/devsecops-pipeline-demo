from datetime import date
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[1]
REQUIRED = ("id", "tool", "subject", "reason", "owner", "expires")


def test_exceptions_have_reason_owner_and_unexpired_date():
    document = yaml.safe_load((ROOT / "security" / "exceptions.yml").read_text())
    assert document["version"] == 1
    assert document["policy"]["fail_on"] == ["HIGH", "CRITICAL"]
    seen: set[str] = set()
    for item in document["exceptions"]:
        for key in REQUIRED:
            assert str(item.get(key, "")).strip(), key
        assert item["id"] not in seen
        seen.add(item["id"])
        assert len(" ".join(item["reason"].split())) >= 40
        raw_expires = item["expires"]
        expires = (
            raw_expires if isinstance(raw_expires, date) else date.fromisoformat(str(raw_expires))
        )
        assert expires >= date.today(), item["id"]
        assert item["owner"] == "aidarshakirovr"
    assert {"EX-001", "EX-002"} <= seen


def test_image_exception_matches_the_trivy_gate():
    makefile = (ROOT / "Makefile").read_text()
    document = yaml.safe_load((ROOT / "security" / "exceptions.yml").read_text())
    assert "--ignore-unfixed" in makefile
    image_exceptions = [item for item in document["exceptions"] if item["tool"] == "trivy-image"]
    assert [item["id"] for item in image_exceptions] == ["EX-002"]


def test_gitleaks_allowlist_matches_documented_exception():
    gitleaks = (ROOT / ".gitleaks.toml").read_text()
    demo = (ROOT / "security" / "gitleaks-demo.toml").read_text()
    assert "fixtures/vulnerable" in gitleaks
    assert "EX-001" in gitleaks
    assert "[allowlist]" not in demo
