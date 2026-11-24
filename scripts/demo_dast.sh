#!/usr/bin/env bash
# Serve a page without the headers marked FAIL and expect the ZAP gate to fail.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT}"

IMAGE="${BAD_IMAGE:-python:3.12-slim-bookworm@sha256:44cf1793efa7c7a476bb0f2cff81443f4a072c90c1cb127e2924933daa3e8c64}"
APP="bad-dast"

cleanup() {
  docker rm -f "${APP}" >/dev/null 2>&1 || true
}
trap cleanup EXIT

docker rm -f "${APP}" >/dev/null 2>&1 || true
docker run -d --name "${APP}" \
  -v "${ROOT}/scripts/bad_dast_target.py:/srv/bad.py:ro" \
  "${IMAGE}" \
  python /srv/bad.py >/dev/null

ready=0
for _ in $(seq 1 30); do
  if docker exec "${APP}" python -c 'import urllib.request; urllib.request.urlopen("http://127.0.0.1:8000/", timeout=2)' >/dev/null 2>&1; then
    ready=1
    break
  fi
  sleep 1
done
if [[ "${ready}" -ne 1 ]]; then
  docker logs "${APP}" || true
  echo "insecure target did not start" >&2
  exit 1
fi

set +e
bash "${ROOT}/scripts/zap_baseline.sh" \
  "http://127.0.0.1:8000" \
  "container:${APP}" \
  "/" \
  "0" \
  "zap-bad.json" \
  "zap-bad.html"
status=$?
set -e

if [[ "${status}" -eq 0 ]]; then
  echo "UNEXPECTED: DAST gate passed on the insecure response"
  exit 1
fi

echo "DAST gate failed on the insecure response (exit ${status})"
exit "${status}"
