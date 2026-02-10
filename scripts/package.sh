#!/usr/bin/env bash
set -euox pipefail

ROOT_DIR="$(cd "$(dirname "${0}")/.." && pwd)"
BIN_DIR="${ROOT_DIR}/.bin"
BUILD_DIR="${ROOT_DIR}/build"

source "${ROOT_DIR}/scripts/.util/tools.sh"
source "${ROOT_DIR}/scripts/.util/print.sh"

function main {
  local version token=""
  local mode="pack"
  local build_path="" build_builder="" build_image=""
  local split_images="${RUST_SPLIT_IMAGES:-false}"
  [[ "${split_images}" == "true" || "${split_images}" == "1" ]] && split_images=true || split_images=false
  while [[ "${#}" -ne 0 ]]; do
    case "${1}" in
      --version|-v) version="${2}"; shift 2 ;;
      --token|-t) token="${2}"; shift 2 ;;
      --build-app) mode="build"; shift 1 ;;
      --path) build_path="${2}"; shift 2 ;;
      --builder) build_builder="${2}"; shift 2 ;;
      --image) build_image="${2}"; shift 2 ;;
      --split-images) split_images=true; shift 1 ;;
      --no-split-images) split_images=false; shift 1 ;;
      --help|-h) usage; exit 0 ;;
      *) util::print::error "unknown argument ${1}" ;;
    esac
  done

  if [[ "${mode}" == "pack" ]]; then
    [[ -z "${version:-}" ]] && { usage; util::print::error "--version is required"; }
    repo::prepare
    tools::install "${token}"
    buildpack::archive "${version}"
  else
    [[ -z "${build_path:-}" ]] && { usage; util::print::error "--path is required for --build-app"; }
    [[ -z "${build_builder:-}" ]] && { usage; util::print::error "--builder is required for --build-app"; }
    [[ -z "${build_image:-}" ]] && { usage; util::print::error "--image is required for --build-app"; }
    repo::prepare
    tools::install "${token}"
    build::app "${build_path}" "${build_builder}" "${build_image}" "${split_images}"
  fi
}

function usage() {
  cat <<'USAGE'
package.sh --version <version> [--token <token>]
  Package the buildpack for distribution.

package.sh --build-app --path <app-dir> --builder <builder> --image <name> [--split-images] [--token <token>]
  Single-step CI build: pack build (monolith) then optionally split into one image per binary.
  Set RUST_SPLIT_IMAGES=true (or use --split-images) for per-binary images.
  Env vars (BP_RUST_FEATURES, etc.) are passed through to pack build.
USAGE
}

function repo::prepare() {
  util::print::title "Preparing repo..."
  rm -rf "${BUILD_DIR}"
  mkdir -p "${BIN_DIR}" "${BUILD_DIR}"
  export PATH="${BIN_DIR}:${PATH}"
}

function tools::install() {
  util::tools::jam::install --directory "${BIN_DIR}" --token "${1}"
  util::tools::pack::install --directory "${BIN_DIR}" --token "${1}"
}

function buildpack::archive() {
  util::print::title "Packaging buildpack into ${BUILD_DIR}/buildpack.tgz..."
  jam pack --buildpack "${ROOT_DIR}/buildpack.toml" --version "${1}" --offline --output "${BUILD_DIR}/buildpack.tgz"
}

function build::app() {
  local app_path="${1}" builder="${2}" image_name="${3}" split="${4}"
  util::print::title "Building app (monolith) → ${image_name}"
  pack build "${image_name}" \
    --path "${app_path}" \
    --builder "${builder}" \
    --pull-policy if-not-present

  if [[ "${split}" == "true" ]]; then
    util::print::title "Creating per-binary images from monolith"
    local binaries
    binaries=$(docker run --rm "${image_name}" cat /workspace/.rust-binaries 2>/dev/null || docker run --rm "${image_name}" sh -c 'for f in /workspace/bin/*; do [ -f "$f" ] && [ -x "$f" ] && basename "$f"; done' 2>/dev/null)
    local tmp_ctx
    tmp_ctx=$(mktemp -d)
    for bin in ${binaries}; do
      [[ "${bin}" == "public" ]] && continue
      util::print::info "Creating ${image_name}:${bin}"
      printf 'FROM %s\nCMD ["/workspace/bin/%s"]' "${image_name}" "${bin}" | docker build -t "${image_name}:${bin}" -f - "${tmp_ctx}"
    done
    rm -rf "${tmp_ctx}"
    util::print::success "Created ${image_name} + $(echo "${binaries}" | grep -cv "^public$" || true) per-binary image(s)"
  fi
}

main "${@:-}"
