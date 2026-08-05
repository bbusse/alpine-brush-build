#!/usr/bin/env bash
#
# Builds the brush container image from the repo's Containerfile and runs
# the bash_unit test suite in tests/test_*.sh against it.
#
# Usage: tests/run.sh
# Env:
#   CONTAINER_ENGINE  docker or podman (default: auto-detect, docker preferred)
#   BRUSH_VERSION     brush version to build the image with (default: Containerfile's default)
#   BRUSH_PKGREL      apk pkgrel to build the image with (default: Containerfile's default)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

BASH_UNIT_VERSION=2.3.3
BASH_UNIT_SHA256=bd1800f6cf3392a7d13f7c37973f124a56b8a89dc29ea94d5843de1a2f025888
BASH_UNIT_CACHE="${SCRIPT_DIR}/.tools/bash_unit-${BASH_UNIT_VERSION}"

if [[ -z "${CONTAINER_ENGINE:-}" ]]; then
  if command -v docker >/dev/null 2>&1; then
    CONTAINER_ENGINE=docker
  elif command -v podman >/dev/null 2>&1; then
    CONTAINER_ENGINE=podman
  else
    echo "error: neither docker nor podman found on PATH" >&2
    exit 1
  fi
fi
export CONTAINER_ENGINE

if command -v bash_unit >/dev/null 2>&1; then
  BASH_UNIT=bash_unit
else
  if [[ ! -x "${BASH_UNIT_CACHE}" ]]; then
    echo "Fetching bash_unit ${BASH_UNIT_VERSION}..." >&2
    mkdir -p "${SCRIPT_DIR}/.tools"
    tmp="$(mktemp)"
    curl -fsSL -o "${tmp}" \
      "https://raw.githubusercontent.com/bash-unit/bash_unit/v${BASH_UNIT_VERSION}/bash_unit"
    echo "${BASH_UNIT_SHA256}  ${tmp}" | sha256sum -c -
    chmod +x "${tmp}"
    mv "${tmp}" "${BASH_UNIT_CACHE}"
  fi
  BASH_UNIT="${BASH_UNIT_CACHE}"
fi

IMAGE="alpine-brush-build-test:$$"
export IMAGE

cleanup() {
  "${CONTAINER_ENGINE}" rmi "${IMAGE}" >/dev/null 2>&1 || true
}
trap cleanup EXIT

echo "Building ${IMAGE} with ${CONTAINER_ENGINE}..." >&2
build_args=()
[[ -n "${BRUSH_VERSION:-}" ]] && build_args+=(--build-arg "BRUSH_VERSION=${BRUSH_VERSION}")
[[ -n "${BRUSH_PKGREL:-}" ]] && build_args+=(--build-arg "BRUSH_PKGREL=${BRUSH_PKGREL}")
"${CONTAINER_ENGINE}" build -q -t "${IMAGE}" ${build_args[@]+"${build_args[@]}"} -f "${REPO_ROOT}/Containerfile" "${REPO_ROOT}"

cd "${SCRIPT_DIR}"
# Not `exec`: the EXIT trap above must still fire afterwards to remove ${IMAGE}.
"${BASH_UNIT}" test_brush.sh test_container.sh
