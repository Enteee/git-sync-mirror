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
  local token_user="${1:-false}" && ( shift || true )

  local token_final=""

  token_url_encoded="$(rawurlencode "${token}")"

  # assemble token
  if [ "${token_user}" != false ]; then
    token_final+="$(rawurlencode "${token_user}"):"
  fi
  token_final+="${token_url_encoded}"

  if [ "${HTTP_ALLOW_TOKENS_INSECURE}" = true ]; then
    echo "${url}" | sed -nre "s|^\s*http(s{0,1})://(.+)|http\1://${token_final}@\2|ip"
  else
    echo "${url}" | sed -nre "s|^\s*https://(.+)|https://${token_final}@\1|ip"
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
# Synchonize refs from local clone to dst
sync(){
  local local_repo="${1}" && shift
  local dst_repo="${1}" && shift

  (
    cd "${local_repo}"

    git remote update \
      --prune

    # delete all hidden github pull request refs
    git for-each-ref \
      --format='delete %(refname)' \
      "${IGNORE_REFS_PATTERN[@]}" \
    | git update-ref --stdin

    git push \
      --all \
      "${dst_repo}" \
    || [ "${TWO_WAY}" = true ]
    git push \
      --tags \
      "${dst_repo}" \
    || [ "${TWO_WAY}" = true ]

  )
}

#
# Prune refs and forward branch deletion to dst
prune(){
  local local_repo="${1}" && shift
  local dst_repo="${1}" && shift

  (
    cd "${local_repo}"

    git remote update

    # Forward pruning from src to dst
    for ref in $(git remote prune --dry-run origin \
      | sed -nre 's/\s+\*\s+\[would prune\]\s+refs\/(heads|tags)\/(.*)/\2/pg')
    do
      # Only forward pruning to dst if we have a matching ref for src and dst
      local_hash="$(
        git show-ref \
          --hash \
          --heads \
          --tags \
          "${ref}"
      )"
      dst_hash="$(
        git ls-remote \
          --heads \
          --tags \
          "${dst_repo}" \
          "${ref}" \
        | cut -f 1
      )"
      if [ "${local_hash}" = "${dst_hash}" ]; then
        git push \
          --delete \
          "${dst_repo}" \
          "${ref}"
      fi
    done

    # Finally, prune from src
    git remote prune \
      origin
  )
}

#
# Environment
#
DEBUG="${DEBUG:-false}"
if [ "${DEBUG}" = true ]; then set -x; fi

SRC_REPO="${SRC_REPO?Missing source repository}"
SRC_REPO_TOKEN="${SRC_REPO_TOKEN:-""}"
SRC_REPO_TOKEN_USER="${SRC_REPO_TOKEN_USER:-""}"

DST_REPO="${DST_REPO?Missing destination repository}"
DST_REPO_TOKEN="${DST_REPO_TOKEN:-""}"
DST_REPO_TOKEN_USER="${DST_REPO_TOKEN_USER:-""}"

PRUNE="${PRUNE:-false}"
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
  SRC_REPO="$(add_token "${SRC_REPO}" "${SRC_REPO_TOKEN}" "${SRC_REPO_TOKEN_USER}")"
fi

if [ -n "${DST_REPO_TOKEN}" ]; then
  DST_REPO="$(add_token "${DST_REPO}" "${DST_REPO_TOKEN}" "${DST_REPO_TOKEN_USER}")"
fi

# Create user in /etc/passwd
if ! whoami &> /dev/null; then
  if [ -w /etc/passwd ]; then
    echo "${USER_NAME:-default}:x:$(id -u):0:${USER_NAME:-default} user:${HOME}:/sbin/nologin" >> /etc/passwd
  fi
fi

# Create local repositories
LOCAL_REPO_SRC="${LOCAL_REPO_SRC:-"$(mktemp -d)"}"
LOCAL_REPO_DST="${LOCAL_REPO_DST:-"$(mktemp -d)"}"

if [ ! -d "${LOCAL_REPO_SRC}/.git" ]; then
     clone_local_repo "${SRC_REPO}" "${LOCAL_REPO_SRC}"
fi

if [ -z "$(ls -A ${LOCAL_REPO_DST})" ]; then
     clone_local_repo "${DST_REPO}" "${LOCAL_REPO_DST}"
fi

git config --global "http.sslVerify" "${HTTP_TLS_VERIFY}"
git config --global "http.${SRC_REPO}.proxy" "${HTTP_SRC_PROXY}"
git config --global "http.${DST_REPO}.proxy" "${HTTP_DST_PROXY}"



while true; do

  if [ "${PRUNE}" = true ]; then
    prune "${LOCAL_REPO_SRC}" "${DST_REPO}"
    if [ "${TWO_WAY}" = true ]; then
      prune "${LOCAL_REPO_DST}" "${SRC_REPO}"
    fi
  fi

  sync "${LOCAL_REPO_SRC}" "${DST_REPO}"
  if [ "${TWO_WAY}" = true ]; then
    sync "${LOCAL_REPO_DST}" "${SRC_REPO}"
  fi

  if [ "${ONCE}" = true ]; then
    exit 0
  fi

  sleep "${SLEEP_TIME}"
done
