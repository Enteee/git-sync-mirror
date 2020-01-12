#!/usr/bin/env bash
set -euo pipefail

#
# Functions
#

#
# Apply url encoding to first argument
# from: https://stackoverflow.com/a/10660730/3215929
rawurlencode(){
  local string="${1}"
  local strlen=${#string}
  local encoded=""
  local pos c o

  for (( pos=0 ; pos<strlen ; pos++ )); do
     c=${string:$pos:1}
     case "$c" in
        [-_.~a-zA-Z0-9] ) o="${c}" ;;
        * )               printf -v o '%%%02x' "'$c"
     esac
     encoded+="${o}"
  done
  echo "${encoded}"
}

#
# Add http token to repository identifier (enforces https)
add_token(){
  local url="${1}" && shift
  local token="${1}" && shift
  local token_url_encoded
  token_url_encoded="$(rawurlencode "${token}")"
  if [ "${HTTP_ALLOW_TOKENS_INSECURE}" = true ]; then
    echo "${url}" | sed -nre "s|^\s*http(s{0,1})://(.+)|http\1://${token_url_encoded}@\2|ip"
  else
    echo "${url}" | sed -nre "s|^\s*https://(.+)|https://${token_url_encoded}@\1|ip"
  fi
}

#
# Clone repostiory to local folder
clone_local_repo(){
  local src_repo="${1}" && shift
  local local_repo="${1}" && shift

  git clone \
    --mirror \
    "${src_repo}" "${local_repo}"
}

#
# Mirror repository from local clone
mirror(){
  local local_repo="${1}" && shift
  local dst_repo="${1}" && shift

  (
    cd "${local_repo}"

    git remote update

    # delete all hidden github pull request refs
    git for-each-ref \
      --format='delete %(refname)' \
      "${IGNORE_REFS_PATTERN[@]}" \
    | git update-ref --stdin

    # do mirror
    if [ "${MIRROR}" = true ]; then

      git push \
        --mirror \
        "${dst_repo}" \
      || [ "${TWO_WAY}" = true ]

    else

      git push \
        --all \
        "${dst_repo}" \
      || [ "${TWO_WAY}" = true ]
      git push \
        --tags \
        "${dst_repo}" \
      || [ "${TWO_WAY}" = true ]

    fi
  )
}

#
# Environment
#
DEBUG="${DEBUG:-false}"
if [ "${DEBUG}" = true ]; then set -x; fi

SRC_REPO="${SRC_REPO?Missing source repository}"
SRC_REPO_TOKEN="${SRC_REPO_TOKEN:-""}"

DST_REPO="${DST_REPO?Missing destination repository}"
DST_REPO_TOKEN="${DST_REPO_TOKEN:-""}"

MIRROR="${MIRROR:-true}"
TWO_WAY="${TWO_WAY:-false}"

HTTP_TLS_VERIFY="${HTTP_TLS_VERIFY:-true}"
HTTP_SRC_PROXY="${HTTP_SRC_PROXY:-""}"
HTTP_DST_PROXY="${HTTP_DST_PROXY:-""}"

ONCE="${ONCE:-false}"
SLEEP_TIME="${SLEEP_TIME:-60s}"

IGNORE_REFS_PATTERN="${IGNORE_REFS_PATTERN:-refs/pull}"

HTTP_ALLOW_TOKENS_INSECURE="${HTTP_ALLOW_TOKENS_INSECURE-false}"

# Add token to repo identifier
if [ -n "${SRC_REPO_TOKEN}" ]; then
  SRC_REPO="$(add_token "${SRC_REPO}" "${SRC_REPO_TOKEN}")"
fi

if [ -n "${DST_REPO_TOKEN}" ]; then
  DST_REPO="$(add_token "${DST_REPO}" "${DST_REPO_TOKEN}")"
fi

# Create local repositories
LOCAL_REPO_SRC="$(mktemp -d)"
LOCAL_REPO_DST="$(mktemp -d)"

git config --global "http.sslVerify" "${HTTP_TLS_VERIFY}"
git config --global "http.${SRC_REPO}.proxy" "${HTTP_SRC_PROXY}"
git config --global "http.${DST_REPO}.proxy" "${HTTP_DST_PROXY}"

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
