#!/usr/bin/env bash
# Install pinned scanner binaries and Python tools.
# Usage: scripts/install-scanners.sh [gitleaks|trivy|hadolint|syft|sast|sca|iac|security]
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST="${HOME}/.local/bin"
mkdir -p "${DEST}"
TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "missing required command: $1" >&2
    exit 1
  }
}

case "$(uname -m)" in
  x86_64|amd64) ;;
  *)
    echo "install-scanners.sh supports linux/amd64 only (found $(uname -m))" >&2
    exit 1
    ;;
esac

download_checked() {
  local url="$1"
  local file="$2"
  local sha="$3"
  need_cmd curl
  need_cmd sha256sum
  curl -fsSL -o "${TMP}/${file}" "${url}"
  echo "${sha}  ${TMP}/${file}" | sha256sum -c -
}

install_gitleaks() {
  if "${DEST}/gitleaks" version 2>/dev/null | grep -q '^8\.30\.1$'; then
    return
  fi
  download_checked \
    "https://github.com/gitleaks/gitleaks/releases/download/v8.30.1/gitleaks_8.30.1_linux_x64.tar.gz" \
    "gitleaks.tar.gz" \
    "551f6fc83ea457d62a0d98237cbad105af8d557003051f41f3e7ca7b3f2470eb"
  tar -xzf "${TMP}/gitleaks.tar.gz" -C "${TMP}" gitleaks
  install -m 0755 "${TMP}/gitleaks" "${DEST}/gitleaks"
}

install_trivy() {
  if "${DEST}/trivy" --version 2>/dev/null | grep -q '0\.76\.2'; then
    return
  fi
  download_checked \
    "https://github.com/aquasecurity/trivy/releases/download/v0.76.2/trivy_0.76.2_Linux-64bit.tar.gz" \
    "trivy.tar.gz" \
    "bc0fc726e017b8927a62b2d3531d7a84ee01769daf5c99ed866dced54089fdbf"
  tar -xzf "${TMP}/trivy.tar.gz" -C "${TMP}" trivy
  install -m 0755 "${TMP}/trivy" "${DEST}/trivy"
}

install_hadolint() {
  if "${DEST}/hadolint" --version 2>/dev/null | grep -q '2\.15\.1'; then
    return
  fi
  download_checked \
    "https://github.com/hadolint/hadolint/releases/download/v2.15.1/hadolint-linux-x86_64" \
    "hadolint" \
    "c7187db94eeeeca956519a6af171adc31453941a1e777961f6e680f697c8c507"
  install -m 0755 "${TMP}/hadolint" "${DEST}/hadolint"
}

install_syft() {
  if "${DEST}/syft" version 2>/dev/null | grep -q '1\.57\.2'; then
    return
  fi
  download_checked \
    "https://github.com/anchore/syft/releases/download/v1.57.2/syft_1.57.2_linux_amd64.tar.gz" \
    "syft.tar.gz" \
    "ad92bd3ec1b94a3df01d4d0aec199afa9c42b72e86da436ff5f837914d32706b"
  tar -xzf "${TMP}/syft.tar.gz" -C "${TMP}" syft
  install -m 0755 "${TMP}/syft" "${DEST}/syft"
}

ensure_venv() {
  local venv_dir="$1"
  if [[ ! -x "${venv_dir}/bin/python" ]]; then
    python3 -m venv "${venv_dir}"
  fi
}

install_python_requirements() {
  local req="$1"
  local venv_dir="$2"
  ensure_venv "${venv_dir}"
  "${venv_dir}/bin/pip" install --disable-pip-version-check --upgrade -r "${ROOT}/${req}"
}

targets=("$@")
if [[ ${#targets[@]} -eq 0 ]]; then
  targets=(gitleaks trivy hadolint syft security)
fi

for target in "${targets[@]}"; do
  case "${target}" in
    gitleaks) install_gitleaks ;;
    trivy) install_trivy ;;
    hadolint) install_hadolint ;;
    syft) install_syft ;;
    sast) install_python_requirements requirements-sast.txt "${ROOT}/.venv-sast" ;;
    sca) install_python_requirements requirements-sca.txt "${ROOT}/.venv" ;;
    iac) install_python_requirements requirements-iac.txt "${ROOT}/.venv-iac" ;;
    security)
      install_python_requirements requirements-sast.txt "${ROOT}/.venv-sast"
      install_python_requirements requirements-sca.txt "${ROOT}/.venv"
      install_python_requirements requirements-iac.txt "${ROOT}/.venv-iac"
      ;;
    *)
      echo "unknown scanner target: ${target}" >&2
      exit 1
      ;;
  esac
done

echo "scanners ready: ${targets[*]}"
