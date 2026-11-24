#!/usr/bin/env bash
# Baseline the application image. Missing security headers are FAIL in security/zap/rules.tsv.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT}"

IMAGE="${IMAGE:-devsecops-demo:local}"
APP="devsecops-app"

cleanup() {
  docker rm -f "${APP}" >/dev/null 2>&1 || true
}
trap cleanup EXIT

docker rm -f "${APP}" >/dev/null 2>&1 || true
docker run -d --name "${APP}" -p 127.0.0.1:8000:8000 "${IMAGE}" >/dev/null

ready=0
for _ in $(seq 1 30); do
  if python3 -c 'import urllib.request; urllib.request.urlopen("http://127.0.0.1:8000/health", timeout=2)' >/dev/null 2>&1; then
    ready=1
    break
  fi
  sleep 1
done
if [[ "${ready}" -ne 1 ]]; then
  docker logs "${APP}" || true
  echo "application did not become healthy" >&2
  exit 1
fi

bash "${ROOT}/scripts/zap_baseline.sh" "http://127.0.0.1:8000" "container:${APP}"
