import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
WORKFLOWS = ROOT / ".github" / "workflows"
PINNED_ACTION = re.compile(r"^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+(?:/[A-Za-z0-9_.-]+)?@[0-9a-f]{40}$")


def _workflow_texts():
    return {path.name: path.read_text() for path in sorted(WORKFLOWS.glob("*.yml"))}


def test_workflows_pin_actions_and_avoid_dangerous_triggers():
    texts = _workflow_texts()
    assert set(texts) == {"ci.yml", "demo-gate-failure.yml"}
    for name, text in texts.items():
        assert "pull_request_target" not in text, name
        assert "secrets." not in text, name
        assert "contents: write" not in text, name
        assert "id-token:" not in text, name
        assert "persist-credentials: false" in text, name
        uses = re.findall(r"^\s*uses:\s*(\S+)", text, re.MULTILINE)
        assert uses, name
        for item in uses:
            assert PINNED_ACTION.match(item), (name, item)


def test_demo_workflow_is_manual_and_main_workflow_is_least_privilege():
    texts = _workflow_texts()
    demo = texts["demo-gate-failure.yml"]
    ci = texts["ci.yml"]
    assert "workflow_dispatch:" in demo
    assert "pull_request:" not in demo
    assert "push:" not in demo
    assert "security-events:" not in demo
    assert "pull_request:" in ci
    assert "security-events: write" in ci
    assert "contents: read" in ci


def test_image_build_does_not_copy_fixtures():
    dockerfile = (ROOT / "Dockerfile").read_text()
    dockerignore = (ROOT / ".dockerignore").read_text()
    assert "COPY app ./app" in dockerfile
    assert "COPY requirements.txt ." in dockerfile
    assert "fixtures" not in dockerfile
    assert "fixtures" in dockerignore
    assert "USER 10001" in dockerfile


def test_sca_gate_targets_production_requirements_only():
    makefile = (ROOT / "Makefile").read_text()
    assert "trivy fs --scanners vuln --severity HIGH,CRITICAL" in makefile
    assert "pip-audit -r requirements.txt" in makefile
    assert "fixtures/vulnerable" not in makefile
