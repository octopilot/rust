#!/usr/bin/env bash
set -eux
set -o pipefail
source "$(dirname "${BASH_SOURCE[0]}")/print.sh"

function util::tools::os() {
  case "$(uname)" in
    "Darwin") echo "${1:-darwin}" ;;
    "Linux") echo "linux" ;;
    *) util::print::error "Unknown OS \"$(uname)\"" ;;
  esac
}

function util::tools::arch() {
  case "$(uname -m)" in
    arm64|aarch64) echo "arm64" ;;
    amd64|x86_64)
      [[ "${1:-}" == "--blank-amd64" ]] && echo "" || echo "amd64"
      ;;
    *) util::print::error "Unknown Architecture \"$(uname -m)\"" ;;
  esac
}

function util::tools::path::export() {
  local dir="${1}"
  if ! echo "${PATH}" | grep -q "${dir}"; then
    PATH="${dir}:$PATH"
    export PATH
  fi
}

# Retry curl up to 3 times on 5xx or connection errors (transient GitHub/CDN failures).
# Use "|| code=$?" so set -e does not exit on curl failure; then check code and retry.
function util::tools::curl_with_retry() {
  local max_attempts=3 attempt=1 code=0
  while [[ ${attempt} -le ${max_attempts} ]]; do
    code=0; (set +e; curl "$@") || code=$?
    [[ ${code} -eq 0 ]] && return 0
    [[ ${attempt} -lt ${max_attempts} ]] && sleep $((attempt * 5))
    attempt=$((attempt + 1))
  done
  return ${code}
}

function util::tools::jam::install() {
  local dir token=""
  while [[ "${#}" != 0 ]]; do
    case "${1}" in
      --directory) dir="${2}"; shift 2 ;;
      --token) token="${2}"; shift 2 ;;
      *) util::print::error "unknown argument \"${1}\"" ;;
    esac
  done
  mkdir -p "${dir}"
  util::tools::path::export "${dir}"
  if [[ ! -f "${dir}/jam" ]]; then
    local version os arch curl_args
    version="$(jq -r .jam "$(dirname "${BASH_SOURCE[0]}")/tools.json")"
    os=$(util::tools::os)
    arch=$(util::tools::arch)
    util::print::title "Installing jam ${version}"
    curl_args=(-fsSL -o "${dir}/jam")
    [[ -n "${token}" ]] && curl_args+=(--header "Authorization: Token ${token}")
    util::tools::curl_with_retry "${curl_args[@]}" "https://github.com/paketo-buildpacks/jam/releases/download/${version}/jam-${os}-${arch}"
    chmod +x "${dir}/jam"
  else
    util::print::info "Using $("${dir}"/jam version)"
  fi
}

function util::tools::pack::install() {
  local dir token=""
  while [[ "${#}" != 0 ]]; do
    case "${1}" in
      --directory) dir="${2}"; shift 2 ;;
      --token) token="${2}"; shift 2 ;;
      *) util::print::error "unknown argument \"${1}\"" ;;
    esac
  done
  mkdir -p "${dir}"
  util::tools::path::export "${dir}"
  if [[ ! -f "${dir}/pack" ]]; then
    local version os arch tmp_location="/tmp/pack.tgz" curl_args
    version="$(jq -r .pack "$(dirname "${BASH_SOURCE[0]}")/tools.json")"
    os=$(util::tools::os macos)
    arch=$(util::tools::arch --blank-amd64)
    util::print::title "Installing pack ${version}"
    curl_args=(-fsSL -o "${tmp_location}")
    [[ -n "${token}" ]] && curl_args+=(--header "Authorization: Token ${token}")
    util::tools::curl_with_retry "${curl_args[@]}" "https://github.com/buildpacks/pack/releases/download/${version}/pack-${version}-${os}${arch:+-$arch}.tgz"
    tar xzf "${tmp_location}" -C "${dir}"
    chmod +x "${dir}/pack"
    rm "${tmp_location}"
  else
    util::print::info "Using pack $("${dir}"/pack version)"
  fi
}
