#!/usr/bin/env bash
# Run the same classes of gates against fixtures/vulnerable.
# Exit 0 only when every gate reports the expected finding.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT}"
export PATH="${ROOT}/.venv-sast/bin:${ROOT}/.venv/bin:${ROOT}/.venv-iac/bin:${HOME}/.local/bin:${PATH}"
export SEMGREP_SEND_METRICS=off

failed=0

expect_fail() {
  local name="$1"
  local marker="$2"
  shift 2
  echo "===== ${name} ====="
  local log status
  log="$(mktemp)"
  set +e
  "$@" >"${log}" 2>&1
  status=$?
  set -e
  cat "${log}"
  if [[ "${status}" -eq 0 ]]; then
    echo "UNEXPECTED PASS: ${name}"
    failed=1
  elif [[ "${status}" -eq 127 ]]; then
    echo "MISSING TOOL: ${name}"
    failed=1
  elif ! grep -q "${marker}" "${log}"; then
    echo "UNEXPECTED OUTPUT: ${name} exited ${status} without marker ${marker}"
    failed=1
  else
    echo "CAUGHT: ${name} (exit ${status})"
  fi
  rm -f "${log}"
}

expect_fail "gitleaks" "leaks found" \
  gitleaks detect --no-git --source fixtures/vulnerable --config security/gitleaks-demo.toml --redact --no-banner --exit-code 1

expect_fail "bandit" "B602" \
  bandit -r fixtures/vulnerable/app.py -lll -iii

expect_fail "semgrep" "subprocess-shell-true" \
  semgrep scan --config p/python --severity ERROR --error --metrics=off --disable-version-check fixtures/vulnerable/app.py

expect_fail "pip-audit" "PYSEC-2021-142" \
  pip-audit -r fixtures/vulnerable/requirements.txt --progress-spinner off --vulnerability-service osv

expect_fail "trivy-fs" "CVE-2020-14343" \
  trivy fs --scanners vuln --severity HIGH,CRITICAL --exit-code 1 --timeout 10m fixtures/vulnerable/requirements.txt

expect_fail "hadolint" "DL3004" \
  hadolint --failure-threshold error fixtures/vulnerable/Dockerfile

expect_fail "checkov" "FAILED" \
  checkov -f fixtures/vulnerable/Dockerfile --framework dockerfile --quiet

expect_fail "trivy-config" "DS-0010" \
  trivy config --severity HIGH,CRITICAL --exit-code 1 --timeout 10m fixtures/vulnerable/Dockerfile

if [[ "${failed}" -ne 0 ]]; then
  echo "demo-fail: one or more gates did not catch the fixture"
  exit 1
fi

echo "demo-fail: every gate caught the vulnerable fixture"
exit 0
