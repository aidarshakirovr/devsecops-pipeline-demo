#!/usr/bin/env bash
# ZAP baseline against the locally built image. Fails on High alerts only (-I).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT}"

IMAGE="${IMAGE:-devsecops-demo:local}"
# ghcr.io/zaproxy/zaproxy:2.17.0
ZAP_IMAGE="${ZAP_IMAGE:-ghcr.io/zaproxy/zaproxy@sha256:9624669db72f54d86c4b46a7064518bd9bf79d8c61a4c31befa9923489f328af}"
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

mkdir -p build
chmod 0777 build
# Share the app network namespace so the scanner reaches 127.0.0.1 even when
# bridge routing between containers is blocked.
docker run --rm --network "container:${APP}" --user root \
  -v "${ROOT}/build:/zap/wrk:rw" \
  "${ZAP_IMAGE}" \
  zap-baseline.py -t "http://127.0.0.1:8000" -I -J zap-baseline.json -r zap-baseline.html
