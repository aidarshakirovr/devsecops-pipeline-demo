PYTHON ?= python3
VENV ?= .venv/bin
SAST ?= .venv-sast/bin
CHECKOV ?= .venv-iac/bin/checkov
IMAGE ?= devsecops-demo:local
BUILD_DIR ?= build

export PATH := $(HOME)/.local/bin:$(PATH)
export SEMGREP_SEND_METRICS := off
export PIP_DISABLE_PIP_VERSION_CHECK := 1

.DEFAULT_GOAL := help

.PHONY: help install install-dev install-scanners lint test verify secrets sast sca iac \
	image-build image-report image-scan sbom dast image demo-fail demo-dast

help:
	@printf '%s\n' \
	  'make install-dev       app + test/lint dependencies' \
	  'make install-scanners  pinned gitleaks, trivy, hadolint, syft, bandit, semgrep, pip-audit, checkov' \
	  'make verify            lint, tests, and local gates that do not need Docker' \
	  'make secrets|sast|sca|iac' \
	  'make image-build       build the runtime image' \
	  'make image-scan        Trivy image gate (HIGH/CRITICAL with a fix)' \
	  'make sbom              CycloneDX from Trivy and Syft' \
	  'make dast              ZAP baseline against the running image' \
	  'make image             build, scan, SBOM, DAST' \
	  'make demo-fail         reproduce static gate failures on the vulnerable fixtures' \
	  'make demo-dast         ZAP baseline against an insecure response; exits non-zero'

install-dev:
	$(PYTHON) -m venv .venv
	$(VENV)/pip install --disable-pip-version-check -r requirements-dev.txt

install-scanners:
	bash scripts/install-scanners.sh

lint:
	$(VENV)/ruff check app tests
	$(VENV)/ruff format --check app tests

test:
	$(VENV)/pytest

verify: lint test secrets sast sca iac

secrets:
	mkdir -p $(BUILD_DIR)
	gitleaks detect --source . --config .gitleaks.toml --redact --no-banner \
	  --report-format sarif --report-path $(BUILD_DIR)/gitleaks.sarif --exit-code 1

sast:
	mkdir -p $(BUILD_DIR)
	$(SAST)/bandit -r app -lll -iii
	$(SAST)/semgrep scan --config p/python --severity ERROR --error --metrics=off \
	  --disable-version-check --sarif --output $(BUILD_DIR)/semgrep.sarif app

sca:
	mkdir -p $(BUILD_DIR)
	$(VENV)/pip-audit -r requirements.txt --progress-spinner off --vulnerability-service osv
	trivy fs --scanners vuln --severity HIGH,CRITICAL --exit-code 1 --timeout 10m \
	  --format sarif --output $(BUILD_DIR)/trivy-fs.sarif requirements.txt

iac:
	mkdir -p $(BUILD_DIR)
	hadolint --config .hadolint.yaml --failure-threshold error --format sarif Dockerfile > $(BUILD_DIR)/hadolint.sarif
	$(CHECKOV) -f Dockerfile --framework dockerfile --quiet
	$(CHECKOV) -f Dockerfile --framework dockerfile --quiet \
	  -o sarif --output-file-path $(BUILD_DIR)/checkov-docker
	$(CHECKOV) -d .github --framework github_actions --quiet
	$(CHECKOV) -d .github --framework github_actions --quiet \
	  -o sarif --output-file-path $(BUILD_DIR)/checkov-gha
	trivy config --skip-dirs fixtures --skip-dirs .venv --skip-dirs .venv-sast --skip-dirs .venv-iac \
	  --skip-dirs build --skip-dirs .git \
	  --severity HIGH,CRITICAL --exit-code 1 --timeout 10m \
	  --format sarif --output $(BUILD_DIR)/trivy-config.sarif .

image-build:
	docker build -t $(IMAGE) .

image-report:
	trivy image --scanners vuln --severity HIGH,CRITICAL --exit-code 0 --timeout 10m $(IMAGE)

image-scan:
	mkdir -p $(BUILD_DIR)
	trivy image --scanners vuln --severity HIGH,CRITICAL --ignore-unfixed --exit-code 1 --timeout 10m \
	  --format sarif --output $(BUILD_DIR)/trivy-image.sarif $(IMAGE)

sbom:
	mkdir -p $(BUILD_DIR)
	trivy image --format cyclonedx --exit-code 0 --timeout 10m --output $(BUILD_DIR)/sbom-trivy.cdx.json $(IMAGE)
	syft $(IMAGE) --select-catalogers "-file" -o cyclonedx-json=$(BUILD_DIR)/sbom-syft.cdx.json

dast:
	IMAGE=$(IMAGE) bash scripts/dast.sh

image: image-build image-report image-scan sbom dast

demo-fail:
	bash scripts/demo-fail.sh

demo-dast:
	bash scripts/demo_dast.sh
