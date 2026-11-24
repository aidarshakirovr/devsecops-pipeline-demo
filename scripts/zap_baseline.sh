#!/usr/bin/env bash
# Run ZAP baseline against an already listening target.
# WARN and FAIL both fail this command. The ignore-warnings flag is not used.
set -euo pipefail

TARGET_URL="${1:?target url}"
ZAP_NETWORK="${2:?docker network mode}"
ZAP_PATHS="${3:-/,/health,/items,/openapi.json}"
ZAP_OPENAPI="${4:-1}"
REPORT_JSON="${5:-zap-baseline.json}"
REPORT_HTML="${6:-zap-baseline.html}"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# ghcr.io/zaproxy/zaproxy:2.17.0
ZAP_IMAGE="${ZAP_IMAGE:-ghcr.io/zaproxy/zaproxy@sha256:9624669db72f54d86c4b46a7064518bd9bf79d8c61a4c31befa9923489f328af}"

mkdir -p "${ROOT}/build/zap-home"
rm -f "${ROOT}/build/${REPORT_JSON}" "${ROOT}/build/${REPORT_HTML}"
docker run --rm \
  --network "${ZAP_NETWORK}" \
  --user "$(id -u):$(id -g)" \
  -e HOME=/home/zap \
  -e ZAP_PATHS="${ZAP_PATHS}" \
  -e ZAP_OPENAPI="${ZAP_OPENAPI}" \
  -v "${ROOT}/build/zap-home:/home/zap" \
  -v "${ROOT}/build:/zap/wrk:rw" \
  -v "${ROOT}/security/zap:/zap/config:ro" \
  "${ZAP_IMAGE}" \
  zap-baseline.py \
    -t "${TARGET_URL}" \
    -c /zap/config/rules.tsv \
    --hook /zap/config/hooks.py \
    -J "${REPORT_JSON}" \
    -r "${REPORT_HTML}" \
    -m 1
