#!/usr/bin/env sh
set -euo pipefail

DEBUG="${DEBUG:-false}"
if [ "${DEBUG}" = true ]; then set -x; fi

# Environment
SRC_REPO="${SRC_REPO?Missing source repository}"
DST_REPO="${DST_REPO?Missing destination repository}"

MIRROR="${MIRROR:-true}"
TWO_WAY="${TWO_WAY:-false}"

HTTP_TLS_VERIFY="${HTTP_TLS_VERIFY:-true}"
HTTP_SRC_PROXY="${HTTP_SRC_PROXY:-""}"
HTTP_DST_PROXY="${HTTP_DST_PROXY:-""}"

ONCE="${ONCE:-false}"
SLEEP_TIME="${SLEEP_TIME:-60s}"

IGNORE_REFS_PATTERN="${IGNORE_REFS_PATTERN:-refs/pull}"

LOCAL_REPO_SRC="$(mktemp -d)"
LOCAL_REPO_DST="$(mktemp -d)"

git config --global "http.sslVerify" "${HTTP_TLS_VERIFY}"
git config --global "http.${SRC_REPO}.proxy" "${HTTP_SRC_PROXY}"
git config --global "http.${DST_REPO}.proxy" "${HTTP_DST_PROXY}"

function clone_local_repo(){
  local src_repo="${1}" && shift
  local local_repo="${1}" && shift

  git clone \
    --mirror \
    "${src_repo}" "${local_repo}"
}

function mirror(){
  local local_repo="${1}" && shift
  local dst_repo="${1}" && shift

  (
    cd "${local_repo}"

    git remote update

    # delete all hidden github pull request refs
    git for-each-ref \
      --format='delete %(refname)' \
      "${IGNORE_REFS_PATTERN}" \
    | git update-ref --stdin

    # do mirror
    if [ "${MIRROR}" = true ]; then
      git push \
        --mirror \
        "${dst_repo}"
    else
      git push \
        --all \
        "${dst_repo}"
      git push \
        --tags \
        "${dst_repo}"
    fi
  )
}

clone_local_repo "${SRC_REPO}" "${LOCAL_REPO_SRC}"
clone_local_repo "${DST_REPO}" "${LOCAL_REPO_DST}"

while true; do

  mirror "${LOCAL_REPO_SRC}" "${DST_REPO}"
  if [ "${TWO_WAY}" = true ]; then
    mirror "${LOCAL_REPO_DST}" "${SRC_REPO}"
  fi

  if [ "${ONCE}" = true ]; then
    exit 0
  fi

  sleep "${SLEEP_TIME}"
done
